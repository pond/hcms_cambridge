$(document).ready(function() {

  // ===========================================================================
  // Copy buttons
  // ===========================================================================
  //
  const copyFromDataButtons = $('button.copy_from_data[data-text]');

  if (copyFromDataButtons.length > 0) {
    copyFromDataButtons.on('click', function(e) {
      const targetButton = $(this);

      text = targetButton.data('text');
      navigator.clipboard.writeText(text);

      icon = targetButton.find('i.fa');
      icon.removeClass('fa-copy');
      icon.addClass('fa-check');

      window.setTimeout(
        function() {
          icon.removeClass('fa-check');
          icon.addClass('fa-copy');
        },
        2000
      );
    });
  }
});
