function reloadMathJax() {

    MathJax.Hub.Queue(["Typeset",MathJax.Hub]);

    console.log("reloadMathJax called");

}

function yak() {

   alert('Yak yak yak yak!');
   // console.log('Yak yak yak yak!');

}


// Up-to-date Cross-Site Request Forgery token
// See: https://github.com/rails/jquery-ujs/blob/master/src/rails.js#L59




function csrfToken() {

    return $('meta[name=csrf-token]').attr('content');
}



$(document).ready(function() {


    $('#Yak').click(yak);

    $('#select_tool_panel').change(function () {
        $('#tools_panel').show();
        $('#toc_panel').hide();
        localStorage.editor_tools = 'show'
        console.log('choose show, localStorage.editor_tools = ' + localStorage.editor_tools)
    });

    $('#select_toc_panel').change(function () {
        $('#tools_panel').hide();
        $('#toc_panel').show();
        localStorage.editor_tools = 'hide'
        console.log('choose hide, localStorage.editor_tools = ' + localStorage.editor_tools)
    });

    $.setup_editor = function () {
        console.log('setup_editor, localStorage.editor_tools = ' + localStorage.editor_tools)
        if (localStorage.editor_tools == 'hide') {
            $('#tools_panel').hide();
            $('#toc_panel').show();
        } else if (localStorage.editor_tools == 'show') {
            $('#tools_panel').show();
            $('#toc_panel').hide();
        } else {
            $('#tools_panel').hide();
            $('#toc_panel').show();
        }
    }

    $.setup_editor();
});