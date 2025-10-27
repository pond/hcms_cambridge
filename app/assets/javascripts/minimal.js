//= require jquery

$(document).ready(function() {
  const buttonsWithConfirmsSelector = $('button[data-confirm]');

  buttonsWithConfirmsSelector.on('click', function(e) {
    var warning = $(this).data('confirm');

    if (!confirm(warning)) {
      e.preventDefault();
      e.stopPropagation();
      return false;
    }
  });
});
