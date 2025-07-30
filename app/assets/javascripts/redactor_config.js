$R.opts.buttons = []

$(document).on('ready page:load', function() {

  var csrf_token = $('meta[name=csrf-token]').attr('content');
  var csrf_param = $('meta[name=csrf-param]').attr('content');
  var params;

  if (csrf_param !== undefined && csrf_token !== undefined)
  {
      params = csrf_param + "=" + encodeURIComponent(csrf_token);
  }

  $R(
    '.custom_redactor',
    {
      path:            "/assets/redactor3-rails",
      fileUpload:      "/redactor3_rails/files?"  + params,
      imageUpload:     "/redactor3_rails/images?" + params,
      imageResizable:  true,
      imagePosition:   true,
      spellcheck:      true,
      minHeight:       '450px',
      maxHeight:       '720px',
      imageFloatMargin: '1em',
      toolbarExternal: "#redactor_toolbar",
      plugins:         [
        'alignment',
        'fontcolor',
        'fontsize',
        // 'properties',
        'table',
        'video',
        'widget',
        'spacer',
      ],
      buttons: [
        'format',
        'alignment',
        'lists',
        'undo',
        'redo',
        'spacer',

        'bold',
        'italic',
        'sup',
        'fontcolor',
        'fontsize',
        'link',
        'spacer',

        'table',
        'image',
        'video',
        'widget',
        'properties',
        'line',
        'spacer',

        'html',
      ],
    }
  );
});
