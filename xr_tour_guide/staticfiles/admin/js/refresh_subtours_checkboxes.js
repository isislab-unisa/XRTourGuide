(function() {
    const originalDismiss = window.dismissAddRelatedObjectPopup;

    window.dismissAddRelatedObjectPopup = function(win, newId, newRepr) {
        originalDismiss(win, newId, newRepr);

        const label = document.createElement('label');
        label.className = 'flex items-center gap-2 p-2 rounded-lg border border-gray-700 bg-gray-900 hover:bg-gray-800 transition-colors';

        label.innerHTML = `
            <input type="checkbox" name="sub_tours" value="${newId}" checked
                   class="h-4 w-4 rounded border-gray-600 bg-gray-800 text-blue-500 focus:ring-2 focus:ring-blue-500 focus:ring-offset-0">
            <span class="text-sm text-gray-200">${newRepr}</span>
        `;

        const subToursContainer = document.querySelector('div#id_sub_tours, div.field-sub_tours');
        if (subToursContainer) {
            subToursContainer.appendChild(label);
        }
    };
})();
