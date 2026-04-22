// (function($) {
//     $(document).ready(function() {
//         function toggleFields() {
//             var category = $("#id_category").val();

//             var tourCoordField = $("#id_coordinates").closest('.form-row, .form-group, .field, .form__field');
//             if (category === "GUIDE") {
//                 tourCoordField.hide();
//             } else {
//                 tourCoordField.show();
//             }

//             $("div.inline-related").each(function() {
//                 var $inline = $(this);

//                 var placeFieldsetInline = $inline.find("input[name$='-place'], select[name$='-place']")
//                                                 .closest("fieldset.module");

//                 var coordFieldsetInline = $inline.find("input[name$='-coordinates']")
//                                                 .closest("fieldset.module");

//                 if (category === "INDOOR" || category === "GUIDE") {
//                     placeFieldsetInline.hide();
//                     coordFieldsetInline.hide();
//                 } else {
//                     placeFieldsetInline.show();
//                     coordFieldsetInline.show();
//                 }
//             });

//             var subToursFieldset = $("#id_sub_tours").closest("fieldset.module");

//             if (category === "MIXED") {
//                 subToursFieldset.show();
//             } else {
//                 subToursFieldset.hide();
//             }
//         }

//         toggleFields();

//         $("#id_category").change(function() {
//             toggleFields();
//         });

//         $(document).on('formset:added', function(event, $row, formsetName) {
//             toggleFields();
//         });
//     });
// })(django.jQuery);


(function ($) {
    $(document).ready(function () {
        function toggleFields() {
            var category = $("#id_category").val();

            var tourCoordField = $("#id_coordinates").closest('.form-row, .form-group, .field, .form__field');
            if (category === "GUIDE") {
                tourCoordField.hide();
            } else {
                tourCoordField.show();
            }

            $("div.inline-related").each(function () {
                var $inline = $(this);

                var placeFieldsetInline = $inline.find("input[name$='-place'], select[name$='-place']")
                    .closest("fieldset.module");

                var coordFieldsetInline = $inline.find("input[name$='-coordinates']")
                    .closest("fieldset.module");

                if (category === "INDOOR" || category === "GUIDE") {
                    placeFieldsetInline.hide();
                    coordFieldsetInline.hide();
                } else {
                    placeFieldsetInline.show();
                    coordFieldsetInline.show();
                }
            });

            var subToursFieldset = $("#id_sub_tours").closest("fieldset.module");

            if (category === "MIXED") {
                subToursFieldset.show();
            } else {
                subToursFieldset.hide();
            }
        }

        function loadWaypointImagesInDetails(detailsEl) {
            if (!detailsEl || !detailsEl.open) {
                return;
            }

            var lazyImages = detailsEl.querySelectorAll("img[data-waypoint-lazy-src]");
            lazyImages.forEach(function (img) {
                if (img.getAttribute("data-waypoint-lazy-loaded") === "1") {
                    return;
                }

                var src = img.getAttribute("data-waypoint-lazy-src");
                if (!src) {
                    return;
                }

                img.setAttribute("src", src);
                img.setAttribute("data-waypoint-lazy-loaded", "1");
                img.removeAttribute("data-waypoint-lazy-src");
            });
        }

        function bindWaypointImageLazyLoading(root) {
            var scope = root || document;
            var detailsPanels = scope.querySelectorAll("details.collapse");

            detailsPanels.forEach(function (detailsEl) {
                if (!detailsEl.querySelector("[data-waypoint-gallery='1']")) {
                    return;
                }
                if (detailsEl.getAttribute("data-waypoint-lazy-bound") === "1") {
                    return;
                }

                detailsEl.setAttribute("data-waypoint-lazy-bound", "1");
                detailsEl.addEventListener("toggle", function () {
                    loadWaypointImagesInDetails(detailsEl);
                });

                // Se il pannello e già aperto, carica subito.
                loadWaypointImagesInDetails(detailsEl);
            });
        }

        toggleFields();
        bindWaypointImageLazyLoading(document);

        $("#id_category").change(function () {
            toggleFields();
        });

        $(document).on("formset:added", function (event, $row) {
            toggleFields();
            bindWaypointImageLazyLoading(($row && $row[0]) || event.target || document);
        });
    });

    function refreshMapsInContainer(container) {
        if (!container) {
            return;
        }

        container.querySelectorAll(".leaflet-container").forEach(function (mapEl) {
            var map = mapEl._locationFieldMap;
            if (!map || mapEl.offsetParent === null) {
                return;
            }

            [0, 150, 400].forEach(function (delay) {
                setTimeout(function () {
                    map.invalidateSize({ pan: false, debounceMoveend: true });
                }, delay);
            });
        });
    }

    document.addEventListener("click", function (event) {
        var header = event.target.closest("h3.cursor-pointer");
        if (!header) {
            return;
        }

        var waypointContainer = header.closest(".form-group, .inline-related");
        if (!waypointContainer) {
            return;
        }

        if (!waypointContainer.querySelector("input[name$='-coordinates']")) {
            return;
        }

        setTimeout(function () {
            refreshMapsInContainer(waypointContainer);
        }, 0);
    });

})(django.jQuery);
