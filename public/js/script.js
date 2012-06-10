/* Author: Yamil Urbina <yamilurbina@gmail.com> */
$(document).ready(function() {
	$('.msg').slideDown().delay(3000).slideUp();

	$('form').each(function(){
		var $that = $(this);
		$that.submit(function(){
			$that.find("input[type='image'],input[type='submit']").attr('disabled', 'true');
		});
	});

	$('a[href="#instance"]').click(function() {
		$('.instance').lightbox_me();
		return false;
	});

	$('a[href="#workspace"]').click(function() {
		$('.workspace').lightbox_me();
		return false;
	});

	$('a[href="#invite"]').click(function() {
		$('.invite').lightbox_me();
		return false;
	});

	$('a[href="#workspace"]').click(function() {
		$('.workspace').lightbox_me();
		return false;
	});
});