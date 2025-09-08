(function($){
    $(document).ready(function(){

        function findMapDivForInput($input) {
            var inputId = $input.attr("id") || "";
            if (inputId.indexOf("__prefix__") !== -1) return $();

            // 1) cerca .map-widget nel form-row più vicino
            var $mapDiv = $input.closest('.form-row, .form-group, .field, .form__field, .inline-related')
                                .find('.map-widget').first();
            if ($mapDiv.length) return $mapDiv;

            // 2) fallback con id costruito
            var suffix = inputId.replace(/^id_/, '');
            $mapDiv = $("#map_" + suffix);
            if ($mapDiv.length) return $mapDiv;

            // 3) fallback con id completo
            $mapDiv = $("#map_" + inputId);
            return $mapDiv;
        }

        function initMapWidget($mapDiv, $input) {
            if (!$mapDiv.length) return;

            // altezza minima
            $mapDiv.css("min-height", "300px");

            // se già inizializzata, forza solo invalidateSize
            if ($mapDiv.data("map-initialized")) {
                if ($mapDiv[0]._leaflet_map && typeof $mapDiv[0]._leaflet_map.invalidateSize === 'function') {
                    setTimeout(function(){ $mapDiv[0]._leaflet_map.invalidateSize(); }, 300);
                }
                return;
            }

            // inizializza il widget Django
            if (typeof $input.init_location_widget === "function") {
                $input.init_location_widget();
                $mapDiv.data("map-initialized", true);

                // fix per eventuali mappe nascoste
                if ($mapDiv[0]._leaflet_map) {
                    setTimeout(function(){ $mapDiv[0]._leaflet_map.invalidateSize(); }, 400);
                }
            } else {
                console.warn("init_location_widget non disponibile per", $input.attr('id'));
            }
        }

        function initAllMaps(context){
            $(context).find("input[id$='-coordinates']").each(function(){
                var $input = $(this);
                if (($input.attr('id') || '').indexOf('__prefix__') !== -1) return;

                var $mapDiv = findMapDivForInput($input);
                initMapWidget($mapDiv, $input);
            });
        }

        // inizializza già presenti
        initAllMaps(document);

        // quando aggiungo inline nuovo
        $(document).on('formset:added', function(event, $row){
            var ctx = $row && $row.length ? $row : $(event.target);
            initAllMaps(ctx);
        });

    });
})(django.jQuery);
