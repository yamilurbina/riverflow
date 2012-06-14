/* Author: Yamil Urbina <yamilurbina@gmail.com> */
$(document).ready(function() {
	$('.msg').fadeIn('slow').delay(4000).fadeOut();

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
		id = $(this).attr('instance_id');
		name = $(this).attr('instance_name');
		$('.workspace h1').text('Add a workspace to ' + name);
		$('#workspace').attr('action', '/workspace/add/' + id)
		$('.workspace').lightbox_me();
		return false;
	});

	$('a[href="#delworkspace"]').click(function() {
		id = $(this).attr('instance_id');
		$('#delworkspace').attr('action', '/workspace/add/' + id)
		$('.delworkspace').lightbox_me();
		return false;
	});

	$('a[href="#invite"]').click(function() {
		$('.invite').lightbox_me();
		return false;
	});
});