/* Author: Yamil Urbina <yamilurbina@gmail.com> */

$(window).load(function() {
	$(this).joyride();
});

$(document).ready(function() {
	$('.msg').fadeIn('slow').delay(4000).fadeOut();

	$('form [title]').tipsy({trigger: 'focus', gravity: 's', opacity: 0.7});

	$('#tipit').tipsy({gravity: 's',opacity: 0.7});


	$('a#eastit').tipsy({gravity: 'w',opacity: 0.6});

	$('a#deleteInstance').tipsy({gravity: 's',opacity: 0.7}).click(function() {
		if(confirm('Are you really, really sure?')) {
			return true;
		}
		else {
			return false;
		}
	});

	$('a[href="#soon"]').tipsy({gravity: 's',opacity: 0.7});

	$('a[href="#domain"]').tipsy({gravity: 's',opacity: 0.6}).click(function() {
		id = $(this).attr('instance_id');
		name = $(this).attr('instance_name');
		$('.domain h2').text('Add an address to ' + name);
		$('#domain').attr('action', '/address/add/' + id);
		$('.domain').lightbox_me();
		return false;
	});

	$('a[href="#instance"]').click(function() {
		$('.instance').lightbox_me();
		return false;
	});

	$('a[href="#workspace"]').click(function() {
		id = $(this).attr('instance_id');
		name = $(this).attr('instance_name');
		$('.workspace h2').text('Add a workspace to ' + name);
		$('#workspace').attr('action', '/workspace/add/' + id);
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

	// A waiting message
	// $('input#waiting').click(function() {
	// 	$('.instance').append('<p>wait.</p>');
	// });

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

	// Add a domain
	$('#domain').isHappy({
		fields: {
			"#addDomain": {
				required: true,
				message: "Where's your domain?",
			}
		}
	});

	// Invite someone
	$('#settings').isHappy({
		fields: {
			"#settingsName": {
				required: true,
				message: "What's your name?"
			},
			"#settingsEmail": {
				required: true,
				message: "Where's your email?",
				test: happy.email
			}
		}
	});

	// Signup form
	$('#signup').isHappy({
		fields: {
			"#signupName": {
				required: true,
				message: "What's your name?"
			},
			"#signupPassword": {
				required: true,
				message: "A password is needed."
			}
		}
	});

	// reset password form
	$('#reset').isHappy({
		fields: {
			"#newPassword": {
				required: true,
				message: "This is required."
			},
			"#rePassword": {
				required: true,
				message: "Repeat your password."
			}
		}
	});
});