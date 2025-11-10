(function() {
    const originalDismiss = window.dismissAddRelatedObjectPopup;

    window.dismissAddRelatedObjectPopup = function(win, newId, newRepr) {
        originalDismiss(win, newId, newRepr);

        const label = document.createElement('label');
        label.innerHTML = `
            <input type="checkbox" name="sub_tours" value="${newId}" checked>
            ${newRepr}
        `;

        const subToursContainer = document.querySelector('div#id_sub_tours, div.field-sub_tours');
        if (subToursContainer) {
            subToursContainer.appendChild(label);
        }
    };
})();
