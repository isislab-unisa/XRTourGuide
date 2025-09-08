(function($) {
    $(document).ready(function() {
        function toggleFields() {
            var category = $("#id_category").val();

            var tourCoordField = $("#id_coordinates").closest('.form-row, .form-group, .field, .form__field');
            if (category === "THING") {
                tourCoordField.hide();
            } else {
                tourCoordField.show();
            }

            $("div.inline-related").each(function() {
                var $inline = $(this);
                var coordField = $inline.find(".waypoint-coordinates-field").closest('.form-row, .form-group, .field, .form__field');
                if (coordField.length === 0) {
                    coordField = $inline.find("input[name$='-coordinates']").closest('.form-row, .form-group, .field, .form__field');
                }
                if (category === "INSIDE" || category === "THING") {
                    coordField.hide();
                } else {
                    coordField.show();
                }
            });

            var subToursField = $("#id_sub_tours").closest('.form-row, .form-group, .field, .form__field');
            if (category === "MIXED") {
                subToursField.show();
            } else {
                subToursField.hide();
            }
        }

        toggleFields();

        $("#id_category").change(function() {
            toggleFields();
        });

        $(document).on('formset:added', function(event, $row, formsetName) {
            toggleFields();
        });
    });
})(django.jQuery);
