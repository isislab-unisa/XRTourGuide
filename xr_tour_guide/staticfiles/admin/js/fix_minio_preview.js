django.jQuery(document).ready(function($) {
    const urlParts = window.location.pathname.split('/');
    const tourId = urlParts[urlParts.length - 3];
    
    const $imageField = $('.field-default_image');
    const $link = $imageField.find('a');
    const $img = $imageField.find('img');
    
    if ($link.length && tourId) {
        const oldUrl = $link.attr('href');
        const filename = oldUrl.split('/').pop().split('?')[0];
        const newUrl = `/stream_minio_resource/?tour=${tourId}&file=${filename}`;
        
        $link.attr('href', newUrl);
        if ($img.length) {
            $img.attr('src', newUrl);
        }
    }
});