# visNetwork import anchor

\`visNetwork\` is a hard dependency of the HLA & TCR Motifs page, but
the renderer lives in \`inst/shiny\` (runtime), not in \`R/\`. This
roxygen anchor imports a symbol so \`R CMD check\` sees the Imports
entry as used. It defines no runtime behaviour.
