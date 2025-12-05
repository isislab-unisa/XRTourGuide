function initMarkdownEditors(context) {
    const textareas = (context || document).querySelectorAll("textarea.markdown-editor");
    

    textareas.forEach(textarea => {
        if (textarea._simplemde) {
            return;
        }

        if (!textarea.offsetParent && textarea.style.display !== 'none') {
            return;
        }

        const initialValue = textarea.value;
        

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
        
    });
}

document.addEventListener("DOMContentLoaded", () => {
    setTimeout(() => initMarkdownEditors(document), 100);
});

document.addEventListener("formset:added", event => {
    setTimeout(() => initMarkdownEditors(event.target), 200);
});

if (typeof django !== 'undefined' && django.jQuery) {
    django.jQuery(document).on('formset:added', function(event) {
        setTimeout(() => initMarkdownEditors(event.target), 200);
    });
}