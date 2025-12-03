function initMarkdownEditors(context) {
    const textareas = (context || document).querySelectorAll("textarea.markdown-editor");
    
    console.log(`Found ${textareas.length} markdown textareas in context`, context);

    textareas.forEach(textarea => {
        if (textarea._simplemde) {
            console.log("Editor already initialized for:", textarea);
            return;
        }

        if (!textarea.offsetParent && textarea.style.display !== 'none') {
            console.log("Textarea not visible yet:", textarea);
            return;
        }

        const initialValue = textarea.value;
        
        console.log("Initializing SimpleMDE for:", textarea);

        const editor = new SimpleMDE({ 
            element: textarea,
            initialValue: initialValue,
            spellChecker: false,
            status: false,
            toolbar: [
                "bold", "italic", "heading", "|",
                "quote", "unordered-list", "ordered-list", "|",
                "link", "image", "|",
                "preview", "side-by-side", "fullscreen", "|",
                "guide"
            ]
        });
        
        textarea._simplemde = editor;
        textarea.classList.add("simplemde-loaded");
        
        console.log("SimpleMDE initialized successfully");
    });
}

document.addEventListener("DOMContentLoaded", () => {
    console.log("DOMContentLoaded - initializing markdown editors");
    setTimeout(() => initMarkdownEditors(document), 100);
});

document.addEventListener("formset:added", event => {
    console.log("Formset added event:", event);
    setTimeout(() => initMarkdownEditors(event.target), 200);
});

if (typeof django !== 'undefined' && django.jQuery) {
    django.jQuery(document).on('formset:added', function(event) {
        console.log("jQuery formset:added event");
        setTimeout(() => initMarkdownEditors(event.target), 200);
    });
}