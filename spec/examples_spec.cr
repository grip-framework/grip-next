# Check if examples compiles

{% for example in read_file("./EXAMPLES.md")
                    .gsub(/require "gripen"/, "require \"../src/gripen\"")
                    .gsub(/require "gripen\//, "require \"../src/")
                    .split("```cr")[1..-1] %}
  {{ example.split("```")[0].id }}
{% end %}
