// (function($) {
//     $(document).ready(function() {

//         function activateWaypointMap(inputElement) {
//             if (!inputElement) return;

//             // initLocationWidget è definita dal JS di django-plain-location
//             if (typeof initLocationWidget === 'function') {
//                 initLocationWidget(inputElement);

//                 // Se la mappa è già renderizzata, forza il resize
//                 if (inputElement._locationMap) {
//                     setTimeout(function() {
//                         inputElement._locationMap.invalidateSize();
//                     }, 100);
//                 }
//             } else {
//                 console.warn("initLocationWidget non definita. Assicurati che plainlocation JS sia caricato.");
//             }
//         }

//         // Attiva le mappe dei waypoint già presenti
//         $('input[id*="map_waypoints-"][id$="-coordinates"]').each(function() {
//             activateWaypointMap(this);
//         });

//         // Attiva le mappe dei nuovi inline aggiunti
//         $(document).on('formset:added', function(event) {
//             const newInline = event.target;
//             if (!newInline) return;

//             const input = $(newInline).find('input[id*="map_waypoints-"][id$="-coordinates"]')[0];
//             if (input) {
//                 console.log("Attivazione mappa per nuovo waypoint");
//                 activateWaypointMap(input);
//             }
//         });

//     });
// })(django.jQuery);
