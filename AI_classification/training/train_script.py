import torch
import torch.nn as nn
import torch.optim as optim
from torch.optim import lr_scheduler
import torch.backends.cudnn as cudnn
from torchvision import datasets, models, transforms
import time
import os
from tempfile import TemporaryDirectory
import torch.nn.functional as F
from tqdm import tqdm
import argparse
import pandas as pd


print("PyTorch Version: ", torch.__version__)
print("CUDA Available: ", torch.cuda.is_available())
# print("CUDA Version: ", torch.version.cuda)
# print("CUDNN Version: ", torch.backends.cudnn.version())

data_transforms = {
    "train": transforms.Compose(
        [
            transforms.RandomResizedCrop(224),
            transforms.RandomHorizontalFlip(),
            transforms.ToTensor(),
            transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
        ]
    ),
    "test": transforms.Compose(
        [
            transforms.Resize(256),
            transforms.CenterCrop(224),
            transforms.ToTensor(),
            transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
        ]
    ),
}

def create_probability_table(model, dataloader, device, class_names):
    model.eval()
    all_probabilities = []
    all_labels = []

    with torch.no_grad():
        for inputs, labels in dataloader:
            inputs = inputs.to(device)
            labels = labels.to(device)
            # Get class name of label
            all_labels.extend([class_names[label] for label in labels.cpu().numpy()])

            outputs = model(inputs)
            probabilities = F.softmax(outputs, dim=1)

            # Round probabilities to 4 floating point
            probabilities = torch.round(probabilities * 10000) / 10000

            all_probabilities.extend(probabilities.cpu().numpy())

    df = pd.DataFrame(all_probabilities, columns=class_names, index=all_labels)
    df.reset_index(inplace=True)
    # Rename the column "index" to "Ground Truth"
    df.rename(columns={"index": "Ground Truth"}, inplace=True)
    # Add all labels as the first column with name "Ground Truth"
    # df.insert(0, "Ground Truth", all_labels)
    return df


def train_model(input_dir, output_dir, num_epochs, run_name, cpu=False):
    try:
        since = time.time()

        image_dataset = {
            x: datasets.ImageFolder(os.path.join(input_dir, x), data_transforms[x])
            for x in ["train", "test"]
        }
        dataloaders = {
            x: torch.utils.data.DataLoader(
                image_dataset[x], batch_size=4, shuffle=True, num_workers=4
            )
            for x in ["train", "test"]
        }
        dataset_sizes = {x: len(image_dataset[x]) for x in ["train", "test"]}
        class_names = image_dataset["train"].classes

        if cpu:
            device = torch.device("cpu")
        else:
            device = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")
        # device = "cpu"

        model_ft = models.swin_v2_b(weights="DEFAULT")
        num_ftrs = model_ft.head.in_features
        model_ft.head = nn.Linear(num_ftrs, len(class_names))
        model = model_ft
        model = model.to(device)

        config_dict = {
            "model": "swin_v2_b",
            "optimizer": "SGD",
            "learning_rate": 0.001,
            "momentum": 0.9,
            "step_size": 7,
            "gamma": 0.1,
            "num_classes": len(class_names),
            "epochs": 100,
        }

        criterion = nn.CrossEntropyLoss()
        optimizer_ft = optim.SGD(
            model_ft.parameters(),
            lr=config_dict["learning_rate"],
            momentum=config_dict["momentum"],
        )
        exp_lr_scheduler = lr_scheduler.StepLR(
            optimizer_ft, step_size=config_dict["step_size"], gamma=config_dict["gamma"]
        )

        final_model_path = os.path.join(
            output_dir, run_name
        )  # Save the final model in the output directory
        os.makedirs(final_model_path, exist_ok=True)
        final_model_path = final_model_path + "/model.pth"

        with TemporaryDirectory() as tempdir:
            best_model_params_path = os.path.join(tempdir, "best_model_params.pt")

            torch.save(model.state_dict(), best_model_params_path)
            best_acc = 0.0

            # Initialize a single progress bar for all epochs
            total_steps = num_epochs * sum(
                len(dataloader) for dataloader in dataloaders.values()
            )
            pbar = tqdm(
                total=total_steps, desc="Training Progress", leave=True, unit="batch"
            )

            for epoch in range(num_epochs):
                # print(f"Epoch {epoch}/{num_epochs - 1}")
                # print("-" * 10)

                epoch_loss = {phase: 0.0 for phase in ["train", "test"]}
                epoch_corrects = {phase: 0 for phase in ["train", "test"]}

                for phase in ["train", "test"]:
                    if phase == "train":
                        model.train()
                    else:
                        model.eval()

                    running_loss = 0.0
                    running_corrects = 0

                    for inputs, labels in dataloaders[phase]:
                        inputs = inputs.to(device)
                        labels = labels.to(device)

                        optimizer_ft.zero_grad()

                        with torch.set_grad_enabled(phase == "train"):
                            outputs = model(inputs)
                            _, preds = torch.max(outputs, 1)
                            loss = criterion(outputs, labels)

                            if phase == "train":
                                loss.backward()
                                optimizer_ft.step()

                        running_loss += loss.item() * inputs.size(0)
                        running_corrects += torch.sum(preds == labels.data)

                        pbar.update(1)
                        pbar.set_postfix(
                            {
                                "epoch": f"{epoch + 1}/{num_epochs}",
                                "train_loss": running_loss / dataset_sizes["train"]
                                if phase == "train"
                                else epoch_loss["train"],
                                "train_acc": (
                                    running_corrects.double() / dataset_sizes["train"]
                                ).item()
                                if phase == "train"
                                else epoch_corrects["train"],
                                "val_loss": running_loss / dataset_sizes["test"]
                                if phase == "test"
                                else epoch_loss["test"],
                                "val_acc": (
                                    running_corrects.double() / dataset_sizes["test"]
                                ).item()
                                if phase == "test"
                                else epoch_corrects["test"],
                            }
                        )

                    if phase == "train":
                        exp_lr_scheduler.step()

                    epoch_loss[phase] = running_loss / dataset_sizes[phase]
                    epoch_corrects[phase] = running_corrects.double() / dataset_sizes[phase]
                    epoch_acc = running_corrects.double() / dataset_sizes[phase]

                    # print(f'{phase} Loss: {epoch_loss:.4f} Acc: {epoch_acc:.4f}')

                    if phase == "test" and epoch_acc > best_acc:
                        best_acc = epoch_acc
                        torch.save(model.state_dict(), best_model_params_path)

                # print()
            pbar.close()

            time_elapsed = time.time() - since
            print(
                f"Training complete in {time_elapsed // 60:.0f}m {time_elapsed % 60:.0f}s"
            )
            print(f"Best val Acc: {best_acc:4f}")

            os.makedirs(os.path.dirname(final_model_path), exist_ok=True)
            # torch.save(model.state_dict(), final_model_path)
            torch.save({
                "model_state_dict": model.state_dict(),
                "class_names": class_names,
            }, final_model_path)
            print(f"Final model saved to {final_model_path}")
            model.load_state_dict(torch.load(best_model_params_path))
            
            probability_table = create_probability_table(
                model, dataloaders["test"], device, class_names
            )
            probability_table_path = os.path.join(output_dir, run_name)
            probability_table.to_csv(
                os.path.join(probability_table_path, "probability_table.csv"), index=False
            )
            print(
                f"Probability table saved to {os.path.join(probability_table_path, 'probability_table.csv')}"
            )
    except Exception as e:
        print(f"Error: {e}")
        return None
    return model


parser = argparse.ArgumentParser(
    description="Train script for image classification using PyTorch."
)
parser.add_argument(
    "--input-dir", type=str, help="Path to the input directory.", required=True
)
parser.add_argument(
    "--output-dir", type=str, help="Path to the output directory.", required=True
)
parser.add_argument(
    "--num-epochs", type=int, default=25, help="Number of epochs to train the model."
)
parser.add_argument(
    "--run-name", type=str, help="Name of the training run.", required=True
)
parser.add_argument(
    "--cpu", action="store_true", help="Use CPU for training."
)
args = parser.parse_args()


model_ft = train_model(args.input_dir, args.output_dir, num_epochs=args.num_epochs, run_name=args.run_name, cpu=args.cpu)
print("Training complete. Model saved to:", args.output_dir + "/" + args.run_name + "/model.pth")
