(function($){
    $(document).ready(function(){

        function initInlineMap($row){
            $row.find("input[id$='-coordinates']").each(function(){
                var $input = $(this);
                if (($input.attr('id') || '').indexOf('__prefix__') !== -1) return;

                // trova il div della mappa relativo all'input
                var $mapDiv = $input.closest('.form-row, .inline-related, .form-group, .field')
                                    .find('.map-widget').first();
                if (!$mapDiv.length) {
                    console.warn("Div mappa non trovato per", $input.attr('id'));
                    return;
                }

                // già inizializzata?
                if ($mapDiv.data("map-initialized")) return;

                // inizializza il widget quando il div è pronto
                var tryInit = function(){
                    if (typeof $input.init_location_widget === "function") {
                        $input.init_location_widget();
                        $mapDiv.data("map-initialized", true);

                        // forza invalidateSize per Leaflet
                        if ($mapDiv[0]._leaflet_map) {
                            setTimeout(function(){ $mapDiv[0]._leaflet_map.invalidateSize(); }, 300);
                        }
                    } else {
                        console.warn("init_location_widget non disponibile per", $input.attr('id'));
                    }
                };

                // se il div non è visibile, aspetta 100ms
                if ($mapDiv.is(":visible")) {
                    tryInit();
                } else {
                    setTimeout(tryInit, 100);
                }
            });
        }

        // inizializza tutte le mappe già presenti
        initInlineMap($(document));

        // inizializza mappe per nuovi inline
        $(document).on('formset:added', function(event, $row){
            var ctx = $row && $row.length ? $row : $(event.target);
            initInlineMap(ctx);
        });

    });
})(django.jQuery);
