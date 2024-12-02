sass::sass(
    input = list(
        sass::sass_file("www/sass/app.scss")
    ),
    output = "www/css/app.min.css",
    options = sass::sass_options(output_style = "compressed")
)
