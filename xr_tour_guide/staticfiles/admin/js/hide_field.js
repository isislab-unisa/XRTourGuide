document.addEventListener('DOMContentLoaded', function () {
    const tourCategorySelect = document.querySelector('#id_category');

    function toggleWaypointCoordinates() {
        const isInside = tourCategorySelect && tourCategorySelect.value.toUpperCase() === 'INSIDE';
        console.log("[DEBUG] Categoria INSIDE:", isInside);

        const coordinateInputs = document.querySelectorAll('.js-waypoint-coordinates');
        coordinateInputs.forEach(input => {
            const wrapper = input.closest('.form-row, .form-group, .field-coordinates, .grid');
            if (wrapper) {
                wrapper.style.display = isInside ? 'none' : '';
            }
        });
    }

    if (tourCategorySelect) {
        toggleWaypointCoordinates();
        tourCategorySelect.addEventListener('change', toggleWaypointCoordinates);
    }

    const observer = new MutationObserver(function () {
        toggleWaypointCoordinates();
    });

    observer.observe(document.body, { childList: true, subtree: true });
});
