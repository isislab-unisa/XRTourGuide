document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll('.inline-related').forEach(form => initMapForForm(form));
});

document.addEventListener('formset:added', function(event) {
    const newForm = event.target;
    const coordInput = newForm.querySelector('input[name$="-coordinates"]');
    if (coordInput) {
        initMapForForm(newForm);
    }
});

function initMapForForm(form) {
    const coordInput = form.querySelector('input[name$="-coordinates"]');
    const placeInput = form.querySelector('input[name$="-place"]');
    if (!coordInput || !placeInput) return;

    const mapContainer = form.querySelector('.leaflet-container');
    if (!mapContainer) return;

    if (mapContainer._leaflet_id) {
        mapContainer._leaflet_id = null;
        mapContainer.innerHTML = '';
    }

    const map = L.map(mapContainer).setView([0, 0], 7);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; OpenStreetMap contributors'
    }).addTo(map);

    let marker = null;

    if (coordInput.value) {
        const [lat, lng] = coordInput.value.split(',').map(Number);
        marker = L.marker([lat, lng]).addTo(map);
        map.setView([lat, lng], 7);
    }

    map.on('click', function(e) {
        coordInput.value = `${e.latlng.lat},${e.latlng.lng}`;
        if (marker) map.removeLayer(marker);
        marker = L.marker([e.latlng.lat, e.latlng.lng]).addTo(map);
    });

    function debounce(func, delay) {
        let timer;
        return function(...args) {
            clearTimeout(timer);
            timer = setTimeout(() => func.apply(this, args), delay);
        };
    }

    function geocodePlace() {
        const query = placeInput.value;
        if (!query) return;

        fetch(`https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(query)}`)
            .then(response => response.json())
            .then(data => {
                if (data && data.length > 0) {
                    const { lat, lon } = data[0];
                    const latNum = parseFloat(lat);
                    const lonNum = parseFloat(lon);
                    coordInput.value = `${latNum},${lonNum}`;
                    if (marker) map.removeLayer(marker);
                    marker = L.marker([latNum, lonNum]).addTo(map);
                    map.setView([latNum, lonNum], 12);
                }
            })
            .catch(err => console.error('Errore geocoding:', err));
    }

    const debouncedGeocode = debounce(geocodePlace, 500);

    placeInput.addEventListener('input', debouncedGeocode);
    placeInput.addEventListener('change', debouncedGeocode);
}

document.addEventListener("DOMContentLoaded", function() {
    const forms = document.querySelectorAll("form");
    forms.forEach(form => {
        form.addEventListener("keydown", function(e) {
            if (e.key === "Enter" && e.target.tagName !== "TEXTAREA") {
                e.preventDefault();
            }
        });
    });
});
