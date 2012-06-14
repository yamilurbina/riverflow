/* Author: Yamil Urbina <yamilurbina@gmail.com> */
$(document).ready(function() {
	$('.msg').fadeIn('slow').delay(4000).fadeOut();

	$('form [title]').tipsy({trigger: 'focus', gravity: 's', opacity: 0.7});

	$('#tipit').tipsy({gravity: 's',opacity: 0.7});

	$('a#eastit').tipsy({gravity: 'w',opacity: 0.6});

	$('a[href="#instance"]').click(function() {
		$('.instance').lightbox_me();
		return false;
	});

	$('a[href="#workspace"]').click(function() {
		id = $(this).attr('instance_id');
		name = $(this).attr('instance_name');
		$('.workspace h2').text('Add a workspace to ' + name);
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

	$('#instanceUrl, #workspaceName').mask('aaaaaaaaaaaaa');

	// Form Validation by Happy.js
	// http://happy.js

	// Login form
	$('#login').isHappy({
		fields: {
			"#yourEmail": {
				required: true,
				message: "Where's your email?",
				test: happy.email
			},
			"#yourPassword": {
				required: true,
				message: "You forgot your password."
			}
		}
	});
	// Adding and instance
	$('#addInstance').isHappy({
		fields: {
			"#instanceTitle": {
				required: true,
				message: "No title? :("
			},
			"#instanceUrl": {
				required: true,
				message: "No subdomain?"
			}
		}
	});

	// Adding a workspace
	$('#workspace').isHappy({
		fields: {
			"#workspaceName": {
				required: true,
				message: "A name is mandatory"
			}
		}
	});

	// Invite someone
	$('#invite').isHappy({
		fields: {
			"#inviteEmail": {
				required: true,
				message: "We do need an email address.",
				test: happy.email
			}
		}
	});
});