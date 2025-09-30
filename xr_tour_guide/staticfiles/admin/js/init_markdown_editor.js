function initMarkdownEditors(context) {
    const textareas = (context || document).querySelectorAll("textarea.markdown-editor");

    textareas.forEach(textarea => {
        if (textarea._simplemde) {
            textarea._simplemde.toTextArea();
            textarea._simplemde = null;
        } else if (textarea.classList.contains("simplemde-loaded")) {
            const wrapper = textarea.parentElement.querySelector(".editor-toolbar");
            if (wrapper) wrapper.remove();
            const codemirror = textarea.parentElement.querySelector(".CodeMirror");
            if (codemirror) codemirror.remove();
            textarea.classList.remove("simplemde-loaded");
        }

        const editor = new SimpleMDE({ element: textarea });
        textarea._simplemde = editor;
        textarea.classList.add("simplemde-loaded");
    });
}

document.addEventListener("DOMContentLoaded", () => initMarkdownEditors(document));
document.addEventListener("formset:added", event => initMarkdownEditors(event.target));

