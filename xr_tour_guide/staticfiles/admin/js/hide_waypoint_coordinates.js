(function($) {
    $(document).ready(function() {
        function toggleFields() {
            var category = $("#id_category").val();

            var tourCoordField = $("#id_coordinates").closest('.form-row, .form-group, .field, .form__field');
            if (category === "GUIDE") {
                tourCoordField.hide();
            } else {
                tourCoordField.show();
            }

            $("div.inline-related").each(function() {
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

        toggleFields();

        $("#id_category").change(function() {
            toggleFields();
        });

        $(document).on('formset:added', function(event, $row, formsetName) {
            toggleFields();
        });
    });
})(django.jQuery);
