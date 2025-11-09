(function($) {
    $(document).ready(function() {
        // Function to refresh subtours checkboxes
        function refreshSubtours() {
            var tourId = $('#tour_form').data('tour-id') || null;
            var currentUrl = window.location.pathname;
            
            // Store currently selected subtours
            var selectedSubtours = [];
            $('input[name="sub_tours"]:checked').each(function() {
                selectedSubtours.push($(this).val());
            });
            
            // Make AJAX request to get updated subtours
            $.ajax({
                url: currentUrl + 'get_subtours/',
                type: 'GET',
                data: {
                    'tour_id': tourId
                },
                success: function(response) {
                    // Update the subtours checkboxes
                    var container = $('#id_sub_tours').parent();
                    container.html(response.html);
                    
                    // Restore selected subtours
                    selectedSubtours.forEach(function(id) {
                        $('input[name="sub_tours"][value="' + id + '"]').prop('checked', true);
                    });
                },
                error: function(xhr, status, error) {
                    console.error('Error refreshing subtours:', error);
                }
            });
        }
        
        // Add refresh button next to subtours field
        var subtourField = $('.field-sub_tours');
        if (subtourField.length) {
            var refreshBtn = $('<button type="button" class="button" style="margin-left: 10px;">Refresh Subtours</button>');
            refreshBtn.on('click', function(e) {
                e.preventDefault();
                refreshSubtours();
            });
            subtourField.find('label').first().append(refreshBtn);
        }
        
        // Optional: Auto-refresh when the page regains focus (user comes back from creating a subtour)
        $(window).on('focus', function() {
            if ($('.field-sub_tours').length) {
                refreshSubtours();
            }
        });
    });
})(django.jQuery);