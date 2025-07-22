window.addEventListener('load', function () {
    const textareas = document.querySelectorAll('textarea.markdown-editor');
    textareas.forEach(textarea => {
        if (!textarea.classList.contains('simplemde-loaded')) {
            new SimpleMDE({ element: textarea });
            textarea.classList.add('simplemde-loaded');
        }
    });
});
