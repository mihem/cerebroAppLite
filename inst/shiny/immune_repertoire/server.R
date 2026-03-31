##----------------------------------------------------------------------------##
## Tab: Immune Repertoire server (unified TCR/BCR)
##
## Uses getImmuneRepertoire() which returns data from the unified
## immune_repertoire field, or falls back to merging legacy bcr_data + tcr_data.
## Chain choices are auto-detected from the CTgene column content.
##----------------------------------------------------------------------------##

local({

  has_scRepertoire <- function() {
    requireNamespace("scRepertoire", quietly = TRUE)
  }

  safeRenderPlot <- function(expr, plot_name = "unknown") {
    tryCatch({
      expr
    }, error = function(e) {
      message("[IR ERROR] Plot '", plot_name, "' failed: ", e$message)
      plot.new()
      text(0.5, 0.5, paste("Error in", plot_name, ":\n", e$message), cex = 0.8)
    })
  }

  ## ---- Detect chain types present in data -------------------------------- ##
  detect_chains <- function(data) {
    if (is.null(data) || !is.list(data) || length(data) == 0) return(character(0))
    # Sample up to 3 elements for efficiency
    sample_dfs <- data[seq_len(min(length(data), 3))]
    all_ct <- unlist(lapply(sample_dfs, function(df) {
      if ("CTgene" %in% names(df)) as.character(df$CTgene) else character(0)
    }))
    chains <- character(0)
    if (any(grepl("TRA", all_ct)))  chains <- c(chains, "TRA")
    if (any(grepl("TRB", all_ct)))  chains <- c(chains, "TRB")
    if (any(grepl("TRG", all_ct)))  chains <- c(chains, "TRG")
    if (any(grepl("TRD", all_ct)))  chains <- c(chains, "TRD")
    if (any(grepl("IGH", all_ct)))  chains <- c(chains, "IGH")
    if (any(grepl("IGK", all_ct)))  chains <- c(chains, "IGK")
    if (any(grepl("IGL", all_ct)))  chains <- c(chains, "IGL")
    chains
  }

  ## ---- Reactive: repertoire data ---------------------------------------- ##
  ir_data <- reactive({
    req(!is.null(data_set()))
    data <- getImmuneRepertoire()
    if (is.null(data) || !is.list(data) || length(data) == 0) return(NULL)
    data
  })

  ## ---- Reactive: parameters --------------------------------------------- ##
  ir_params <- reactive({
    gb <- input$ir_groupBy
    if (is.null(gb) || gb == "") gb <- NULL
    list(
      cloneCall = input$ir_cloneCall,
      chain     = input$ir_chain,
      groupBy   = gb
    )
  })

  ## ---- Reactive: number of groups for faceted plots --------------------- ##
  n_groups <- reactive({
    gb <- ir_params()$groupBy
    if (is.null(gb)) return(1L)
    data <- ir_data()
    if (is.null(data)) return(1L)
    lvls <- unique(unlist(lapply(data, function(df) {
      if (gb %in% names(df)) unique(as.character(df[[gb]])) else character(0)
    })))
    max(1L, length(lvls))
  })

  ## ---- Dynamic gene parameter for vizGenes/percentGeneUsage ------------- ##
  default_gene_family <- reactive({
    chains <- detect_chains(ir_data())
    tcr_chains <- intersect(chains, c("TRA", "TRB", "TRG", "TRD"))
    bcr_chains <- intersect(chains, c("IGH", "IGK", "IGL"))
    if (length(tcr_chains) > 0 && "TRB" %in% tcr_chains) return("TRBV")
    if (length(tcr_chains) > 0) return(paste0(tcr_chains[1], "V"))
    if (length(bcr_chains) > 0 && "IGH" %in% bcr_chains) return("IGHV")
    if (length(bcr_chains) > 0) return(paste0(bcr_chains[1], "V"))
    "TRBV"
  })

  ## ---- Resolve chain: for functions that don't accept "both" ------------ ##
  specific_chain <- reactive({
    ch <- input$ir_chain
    if (is.null(ch) || ch == "both") {
      chains <- detect_chains(ir_data())
      if ("TRB" %in% chains) return("TRB")
      if (length(chains) > 0) return(chains[1])
      return("TRB")
    }
    ch
  })

  ## ---- Count unique genes for dynamic plot height ----------------------- ##
  n_genes <- reactive({
    data <- ir_data()
    if (is.null(data)) return(0L)
    gene_family <- default_gene_family()
    # Gather all gene values across samples
    all_genes <- unique(unlist(lapply(data, function(df) {
      # CTgene has format like "TRBV1.TRBJ2" — extract the gene family portion
      ct <- as.character(df$CTgene)
      ct <- ct[!is.na(ct)]
      # Split by "." and keep segments matching the gene family prefix
      segments <- unlist(strsplit(ct, "[._]"))
      segments[grepl(paste0("^", gene_family), segments, ignore.case = TRUE)]
    })))
    length(all_genes)
  })

  ir_plot_height <- function(facet_mode = c("none", "grid", "wrap")) {
    facet_mode <- match.arg(facet_mode)
    n <- n_genes()
    ng <- n_groups()
    base_h <- max(450, min(n * 25, 2500))
    if (ng <= 1 || facet_mode == "none") return(base_h)
    if (facet_mode == "grid") {
      # facet_grid(Group ~ .): each group stacked vertically
      return(base_h * ng)
    }
    # facet_wrap: ggplot default ncol = ceiling(sqrt(n))
    ncol <- ceiling(sqrt(ng))
    nrow <- ceiling(ng / ncol)
    base_h * nrow
  }

  ## ---- Tab change: update cloneCall choices ----------------------------- ##
  observeEvent(input$ir_tabs, {
    req(has_scRepertoire())
    tab <- input$ir_tabs
    if (tab %in% c("Length", "K-mer")) {
      updateSelectInput(session, "ir_cloneCall",
        choices = c("nt", "aa"),
        selected = if (input$ir_cloneCall %in% c("nt", "aa")) input$ir_cloneCall else "aa"
      )
    } else if (tab %in% c("Gene usage", "vizGenes", "percentGenes",
                           "percentVJ", "AA %", "Entropy")) {
      updateSelectInput(session, "ir_cloneCall", choices = NULL, selected = NULL)
    } else {
      updateSelectInput(session, "ir_cloneCall",
        choices = c("gene", "nt", "aa", "strict"),
        selected = input$ir_cloneCall
      )
    }
    shinyjs::toggleElement(id = "ir_scatter_x", anim = TRUE,
      condition = tab == "Scatter" && n_samples() >= 2)
    shinyjs::toggleElement(id = "ir_scatter_y", anim = TRUE,
      condition = tab == "Scatter" && n_samples() >= 2)
    shinyjs::toggleElement(id = "ir_compare_samples", anim = TRUE,
      condition = tab == "Compare" && n_samples() >= 2)
  })

  ## ---- Settings UI ------------------------------------------------------ ##
  output$ir_settings_UI <- renderUI({
    req(has_scRepertoire())
    data <- ir_data()
    if (is.null(data)) {
      return(div(class = "alert alert-warning",
        "No immune repertoire data available. Import data with TCR/BCR annotations first."))
    }

    available_samples <- names(data)
    chains_present <- detect_chains(data)
    ## Build grouped chain choices: All / TCR / BCR
    tcr_present <- intersect(chains_present, c("TRA", "TRB", "TRG", "TRD"))
    bcr_present <- intersect(chains_present, c("IGH", "IGK", "IGL"))
    chain_choices <- list("All" = "both")
    if (length(tcr_present) > 0)
      chain_choices[["TCR"]] <- as.list(setNames(tcr_present, tcr_present))
    if (length(bcr_present) > 0)
      chain_choices[["BCR"]] <- as.list(setNames(bcr_present, bcr_present))

    all_groups <- getGroups()
    data_cols <- names(data[[1]])
    available_groups <- c(NULL, intersect(all_groups, data_cols))

    tagList(
      tags$style("#ir_chain + .selectize-control .selectize-dropdown-content { max-height: none; }"),
      fluidRow(
        column(6, selectInput("ir_cloneCall", "Clone call:",
          choices = c("gene", "nt", "aa", "strict"), selected = "gene")),
        column(6, selectInput("ir_groupBy", "Group by:",
          choices = c("None" = "", available_groups), selected = ""))
      ),
      fluidRow(
        column(6, selectInput("ir_chain", "Chain:",
          choices = chain_choices, selected = "both"))
      ),
      if (length(available_samples) >= 2) {
        tagList(
          fluidRow(
            column(6, selectInput("ir_scatter_x", "Sample 1 (Scatter):",
              choices = available_samples, selected = available_samples[1])),
            column(6, selectInput("ir_scatter_y", "Sample 2 (Scatter):",
              choices = available_samples, selected = available_samples[2]))
          ),
          fluidRow(
            column(12, selectInput("ir_compare_samples",
              "Samples for Compare (select >= 2):",
              choices = available_samples, multiple = TRUE,
              selected = available_samples[1:2]))
          )
        )
      }
    )
  })

  ## ---- Reactive: number of samples -------------------------------------- ##
  n_samples <- reactive({
    data <- ir_data()
    if (is.null(data)) 0L else length(data)
  })

  ## ---- Help text formatter ---------------------------------------------- ##
  .format_detail <- function(txt) {
    lines <- strsplit(txt, "\n")[[1]]
    out <- list()
    ul_buf <- character(0)
    is_first_para <- TRUE

    ## -- inline markup: 'term' -> bold accent; em-dash split in bullets ----
    .inline <- function(s) {
      # Replace 'quoted' terms with styled <b>
      s <- gsub("'([^']+)'",
        "<b style='color:#2c6fbb;'>\\1</b>", s)
      HTML(s)
    }

    .make_li <- function(raw) {
      txt <- sub("^\\s*\u2022\\s*", "", raw)
      # Split on em-dash: bold the key part, normal the explanation
      if (grepl("\u2014", txt)) {
        parts <- strsplit(txt, "\\s*\u2014\\s*", perl = TRUE)[[1]]
        tagList(
          tags$li(style = "margin: 4px 0; line-height: 1.5;",
            tags$strong(.inline(parts[1])),
            if (length(parts) > 1) tagList(
              " \u2014 ",
              tags$span(style = "color: #555;",
                .inline(paste(parts[-1], collapse = " \u2014 ")))
            )
          )
        )
      } else {
        tags$li(style = "margin: 4px 0; line-height: 1.5;", .inline(txt))
      }
    }

    flush_ul <- function() {
      if (length(ul_buf) > 0) {
        items <- lapply(ul_buf, .make_li)
        out[[length(out) + 1L]] <<- do.call(
          tags$ul, c(items, list(
            style = "padding-left: 22px; margin: 8px 0; list-style-type: disc;"
          )))
        ul_buf <<- character(0)
      }
    }

    for (ln in lines) {
      if (grepl("^\\s*\u2022", ln)) {
        ## bullet line
        ul_buf <- c(ul_buf, ln)
      } else if (trimws(ln) == "") {
        ## blank line -> flush
        flush_ul()
      } else if (grepl(":$", trimws(ln))) {
        ## section header (e.g. "What to look for:")
        flush_ul()
        out[[length(out) + 1L]] <- tags$p(
          style = "margin: 12px 0 4px 0; font-weight: 600; color: #2c6fbb; font-size: 14px;",
          sub(":$", "", trimws(ln))
        )
      } else {
        ## regular paragraph
        flush_ul()
        if (is_first_para) {
          out[[length(out) + 1L]] <- tags$p(
            style = "margin: 6px 0; line-height: 1.6; font-size: 14px;",
            .inline(ln))
          is_first_para <- FALSE
        } else {
          out[[length(out) + 1L]] <- tags$p(
            style = "margin: 6px 0; line-height: 1.6; color: #444;",
            .inline(ln))
        }
      }
    }
    flush_ul()
    do.call(tagList, out)
  }

  ## ---- Help text for each visualization tab ----------------------------- ##
  ir_tab_help <- list(
    Abundance = list(
      short = "Clonal abundance distribution",
      summary = "Ranks clonotypes by cell count. Steep drop-off indicates oligoclonal dominance; gradual decline indicates diverse repertoire.",
      detail = paste(
        "Every T or B cell carries a unique receptor sequence (called a 'clonotype').",
        "Some clonotypes are found in many cells (expanded clones), while most appear only once or twice (rare clones).",
        "",
        "This plot ranks all clonotypes by how many cells carry them.",
        "The X-axis is the rank (1 = most common clone), and the Y-axis is the number of cells.",
        "",
        "What to look for:",
        "\u2022 A steep drop-off means a few clones dominate \u2014 this often happens after infection or in tumors where certain T/B cells multiply rapidly.",
        "\u2022 A flat, gradual curve means many clones are roughly equal in size \u2014 typical of a resting, diverse immune system.",
        "\u2022 Compare samples: if one sample has a much steeper curve, that sample likely experienced stronger clonal expansion.",
        sep = "\n")
    ),
    Diversity = list(
      short = "Repertoire diversity",
      summary = "Quantifies clonotype richness and evenness using Shannon entropy. Higher values reflect broader, more balanced repertoires.",
      detail = paste(
        "Diversity measures how many different clonotypes exist AND how evenly they are distributed.",
        "Think of it like species diversity in an ecosystem \u2014 a forest with 100 equally common tree species is more 'diverse' than one with 100 species where a single species makes up 99%.",
        "",
        "This plot uses Shannon entropy (a mathematical diversity index) with error bars from bootstrap resampling.",
        "",
        "What to look for:",
        "\u2022 Higher values = more diverse repertoire (many clonotypes, evenly distributed).",
        "\u2022 Lower values = less diverse (dominated by a few expanded clones).",
        "\u2022 After vaccination or infection, diversity often drops temporarily as specific clones expand.",
        "\u2022 In autoimmune diseases, you may see persistently low diversity in the affected tissue.",
        "\u2022 Error bars help you judge whether differences between samples are meaningful or just random variation.",
        sep = "\n")
    ),
    Homeostasis = list(
      short = "Clonal homeostasis",
      summary = "Categorises clonotypes into size classes (Rare to Hyperexpanded). Shifts toward larger classes indicate active clonal expansion.",
      detail = paste(
        "This plot groups all clonotypes into size categories based on how many cells carry them:",
        "\u2022 Rare: appears in very few cells",
        "\u2022 Small: slightly more common",
        "\u2022 Medium: moderately expanded",
        "\u2022 Large: substantially expanded",
        "\u2022 Hyperexpanded: found in a very large number of cells",
        "",
        "Each bar shows the proportion of cells belonging to each category for a given sample.",
        "",
        "What to look for:",
        "\u2022 A healthy resting repertoire is mostly 'Rare' and 'Small' clones.",
        "\u2022 After immune activation (infection, vaccination), you'll see more cells shifting into 'Large' and 'Hyperexpanded' categories.",
        "\u2022 Comparing samples side-by-side reveals which conditions drive more clonal expansion.",
        "\u2022 In cancer, tumor-infiltrating lymphocytes often show a high proportion of hyperexpanded clones (indicating anti-tumor response or exhaustion).",
        sep = "\n")
    ),
    Length = list(
      short = "CDR3 length distribution",
      summary = "Distribution of CDR3 region lengths. Shifts in the peak may indicate antigen-driven selection constraining receptor structure.",
      detail = paste(
        "The CDR3 region is the most variable part of a T/B cell receptor \u2014 it's the primary 'fingers' that grab onto antigens (foreign molecules).",
        "CDR3 length directly affects what a receptor can bind to.",
        "",
        "This plot shows how many clonotypes have each possible CDR3 length (in amino acids or nucleotides).",
        "",
        "What to look for:",
        "\u2022 TCR CDR3 lengths typically peak around 12\u201315 amino acids; BCR CDR3 lengths have a wider range.",
        "\u2022 A shift in the peak length between conditions may indicate selection for receptors that bind a specific antigen shape.",
        "\u2022 Very long or very short CDR3 are often self-reactive and may be removed by the immune system (negative selection).",
        "\u2022 If one sample has a narrower length distribution, it suggests selection pressure is constraining which receptors survive.",
        sep = "\n")
    ),
    Proportion = list(
      short = "Clonal proportion",
      summary = "Cumulative fraction of the repertoire occupied by top-ranked clonotypes. Reveals the degree of clonal dominance.",
      detail = paste(
        "Imagine lining up all clonotypes from most common to least common, then asking: 'What percentage of all cells are accounted for by the top 10 clones? Top 100? Top 1000?'",
        "",
        "This plot answers exactly that, splitting clones into cumulative bins.",
        "",
        "What to look for:",
        "\u2022 If the top 10 clones already account for 50% of all cells, the repertoire is highly dominated by a few winners.",
        "\u2022 If even the top 1000 clones account for only a small fraction, the repertoire is very diverse and evenly distributed.",
        "\u2022 Comparing bars across samples shows which sample has more concentrated (or more spread out) immune responses.",
        "\u2022 This is a more intuitive way to see 'clonal dominance' than diversity indices.",
        sep = "\n")
    ),
    Quant = list(
      short = "Unique clonotype count",
      summary = "Total number of distinct clonotypes per sample. Sensitive to sequencing depth; use Rarefaction for size-corrected comparison.",
      detail = paste(
        "The simplest possible question: just count how many distinct receptor sequences exist in each sample.",
        "",
        "What to look for:",
        "\u2022 More unique clonotypes usually = higher diversity.",
        "\u2022 Caution: this number is strongly influenced by how many cells were sequenced. A sample with 10,000 cells will naturally show more unique clonotypes than one with 1,000 cells, even if they're equally diverse. Use Rarefaction to correct for this.",
        "\u2022 Still useful for a quick first look \u2014 large differences between samples of similar size are meaningful.",
        "\u2022 In disease vs. healthy comparisons, reduced clonotype counts in disease tissue may indicate oligoclonal expansion.",
        sep = "\n")
    ),
    Rarefaction = list(
      short = "Rarefaction analysis",
      summary = "Estimates clonotype discovery at subsampled depths. A plateauing curve confirms sufficient sequencing saturation.",
      detail = paste(
        "A critical quality check. Rarefaction asks: 'If we had sequenced fewer cells, how many unique clonotypes would we have found?'",
        "",
        "The plot simulates subsampling your data at different depths and counts clonotypes at each level.",
        "",
        "What to look for:",
        "\u2022 If the curve flattens (plateaus), you've sequenced enough \u2014 adding more cells won't reveal many new clonotypes.",
        "\u2022 If the curve is still rising steeply at the rightmost point, you haven't captured the full diversity and would benefit from sequencing more cells.",
        "\u2022 This is the proper way to compare clonotype counts between samples of different sizes \u2014 compare the curves at the same subsampled depth.",
        "\u2022 The shaded bands show confidence intervals from bootstrap resampling. Wider bands = more uncertainty.",
        "\u2022 Adjust the 'Bootstrap iterations' slider to trade speed for smoother confidence bands.",
        sep = "\n")
    ),
    `Gene usage` = list(
      short = "V(D)J gene usage",
      summary = "Heatmap of V gene segment frequencies across samples. Biased usage may reflect antigen-driven selection or germline accessibility.",
      detail = paste(
        "T and B cell receptors are assembled by randomly joining gene segments called V (Variable), D (Diversity), and J (Joining).",
        "There are ~50+ V segments and ~10+ J segments in the genome, but not all are used equally.",
        "",
        "This heatmap shows how frequently each V gene segment is used across your samples. Rows = gene segments, columns = samples. Darker color = more usage.",
        "",
        "What to look for:",
        "\u2022 Some V genes are naturally used more often than others due to accessibility in the genome.",
        "\u2022 A V gene that is abnormally high in one condition may indicate antigen-driven selection \u2014 the immune system is preferentially expanding clones using that particular gene because it's good at recognizing a specific pathogen.",
        "\u2022 Differences in gene usage between healthy and disease samples can be disease biomarkers.",
        "\u2022 In B cells, comparing IGHV gene usage can reveal biases associated with specific antibody responses.",
        sep = "\n")
    ),
    vizGenes = list(
      short = "Gene usage counts",
      summary = "Raw counts of V/J gene segment usage. Complements the percentage-based heatmap by showing absolute cell numbers.",
      detail = paste(
        "Similar to 'Gene usage' but displays raw counts instead of percentages in a heatmap.",
        "This gives you a sense of both how popular a gene segment is AND how many cells are involved.",
        "",
        "What to look for:",
        "\u2022 High count + high percentage = major gene usage that matters both relatively and absolutely.",
        "\u2022 High percentage but low count could be an artifact of a small sample.",
        "\u2022 Compare with 'Gene usage' (which shows percentages) to get both perspectives.",
        "\u2022 Useful when sample sizes differ significantly \u2014 raw counts show the actual data volume behind each percentage.",
        sep = "\n")
    ),
    percentGenes = list(
      short = "Gene usage percentages",
      summary = "Normalised gene segment usage as a heatmap. Enables fair comparison across samples with different cell counts.",
      detail = paste(
        "Shows each V (or J) gene segment as a percentage of total usage, displayed as a heatmap where columns are samples/groups and rows are individual gene segments.",
        "",
        "What to look for:",
        "\u2022 Hot spots (bright cells) show gene segments that dominate in a particular sample.",
        "\u2022 Gene segments that are bright in disease but dim in healthy (or vice versa) suggest condition-specific gene usage bias.",
        "\u2022 This view is normalized, so it's fair to compare across samples even if they have different total cell counts.",
        "\u2022 Note: this uses the chain selected in the 'Chain' dropdown \u2014 if you see unexpected results, check that you've selected the right chain (e.g., TRB for TCR beta).",
        sep = "\n")
    ),
    percentVJ = list(
      short = "V-J gene pairing",
      summary = "V-J combination frequency heatmap. Enriched pairings may indicate convergent selection for specific antigen-binding configurations.",
      detail = paste(
        "Each clonotype uses one V gene AND one J gene. This heatmap shows how often each V-J combination appears.",
        "Each panel (facet) represents a different sample or group.",
        "",
        "Why this matters:",
        "\u2022 V-J pairing is not random \u2014 some combinations are structurally favored.",
        "\u2022 If a specific V-J combination is unusually enriched in a disease sample, it suggests convergent selection: many independent cells arrived at the same receptor solution in response to the same antigen.",
        "\u2022 'Public' clonotypes (shared across individuals) often use the same V-J pairings.",
        "",
        "What to look for:",
        "\u2022 Bright spots in one panel but not others = condition-specific V-J preferences.",
        "\u2022 A diagonal pattern suggests V and J usage are correlated.",
        "\u2022 Broadly distributed color means diverse V-J usage with no strong preference.",
        sep = "\n")
    ),
    `AA %` = list(
      short = "Positional amino acid composition",
      summary = "Amino acid frequency at each CDR3 position. Conserved positions suggest structural constraints; variable positions drive antigen specificity.",
      detail = paste(
        "The CDR3 region makes direct contact with antigens. This plot shows, at each position along the CDR3, what percentage of clonotypes use each amino acid.",
        "Each group gets its own facet panel, stacked vertically.",
        "",
        "What to look for:",
        "\u2022 Positions near the edges (start and end of CDR3) tend to be conserved \u2014 they are constrained by V and J gene segments.",
        "\u2022 Middle positions are usually more variable \u2014 this is where random nucleotide insertions create diversity.",
        "\u2022 If a certain amino acid dominates a middle position in your disease sample (but not in healthy), it may indicate selection for receptors that bind a specific antigen shape.",
        "\u2022 Glycine (G), Serine (S), and other small amino acids are common in CDR3 due to their structural flexibility.",
        "\u2022 Comparing between conditions reveals position-specific amino acid biases that could be functionally important.",
        sep = "\n")
    ),
    Entropy = list(
      short = "Positional entropy",
      summary = "Shannon entropy at each CDR3 position. Low entropy indicates conservation; high entropy reflects sequence diversification.",
      detail = paste(
        "Entropy measures 'randomness' or 'uncertainty'. At each CDR3 amino acid position, if all clonotypes use the same amino acid, entropy is 0 (completely conserved). If every amino acid appears equally, entropy is maximal (completely random).",
        "",
        "This plot shows normalized Shannon entropy at each position.",
        "",
        "What to look for:",
        "\u2022 Low entropy positions (dips in the curve) are conserved \u2014 structural or functional constraints force most clonotypes to use the same amino acid there.",
        "\u2022 High entropy positions (peaks) are highly variable \u2014 these are the 'creative' spots where diversity is generated.",
        "\u2022 The edges of CDR3 (positions 1\u20133 and last 1\u20133) typically have lower entropy because they are encoded by the V and J gene segments.",
        "\u2022 Comparing entropy profiles between conditions: if a position becomes less random (lower entropy) in disease, it suggests selection pressure at that position.",
        "\u2022 This is a compact summary of the amino acid composition data shown in the 'AA %' tab.",
        sep = "\n")
    ),
    Property = list(
      short = "CDR3 physicochemical profile",
      summary = "Mean physicochemical property values along the CDR3 region. Shifts between conditions reveal structural selection pressures.",
      detail = paste(
        "Amino acids differ in size, charge, hydrophobicity, and other physical/chemical properties. These properties determine how the CDR3 region interacts with antigens.",
        "",
        "This plot shows the average value of a physicochemical property at each CDR3 position, with confidence intervals. Choose different property scales from the dropdown:",
        "\u2022 Atchley Factors: 5 factors capturing size, polarity, charge, etc.",
        "\u2022 Kidera Factors: 10 factors from statistical analysis of amino acid properties.",
        "\u2022 Other scales (FASGAI, zScales, etc.) capture different aspects of amino acid chemistry.",
        "",
        "What to look for:",
        "\u2022 Regions with strong positive or negative property values indicate positions where specific physical properties are required (e.g., a hydrophobic core or a charged tip for antigen binding).",
        "\u2022 Wide confidence intervals mean high variability at that position.",
        "\u2022 Comparing between conditions: shifts in a property at specific positions suggest the disease selects for CDR3 with different physical characteristics.",
        "\u2022 This is particularly useful for understanding WHY certain receptors bind their targets \u2014 it goes beyond sequence to structure.",
        sep = "\n")
    ),
    `K-mer` = list(
      short = "CDR3 k-mer motifs",
      summary = "Top recurring short amino acid subsequences in CDR3. Condition-enriched motifs may mark antigen-specific binding signatures.",
      detail = paste(
        "A 'k-mer' is a short subsequence of fixed length (default: 3 amino acids). This analysis scans all CDR3 sequences, counts every possible 3-amino-acid window, and shows the most frequent ones.",
        "",
        "Think of it as finding the most popular 'building blocks' or 'words' within CDR3 sequences.",
        "",
        "What to look for:",
        "\u2022 Motifs that are frequent in one condition but rare in another may be functionally relevant \u2014 they could be part of the antigen-binding site.",
        "\u2022 Shared motifs across samples suggest 'public' immune responses where different individuals use similar receptor sequences against the same threat.",
        "\u2022 Some motifs are common simply because they arise naturally from popular V/J gene segments.",
        "\u2022 Use the slider to show more or fewer top motifs. Start with 15\u201330 for an overview, increase to 50+ for deeper analysis.",
        sep = "\n")
    ),
    Compare = list(
      short = "Clonotype tracking",
      summary = "Alluvial diagram tracking top clonotypes across samples. Shared ribbons represent public or persistent clones.",
      detail = paste(
        "This alluvial (flow) diagram tracks the top clonotypes across your selected samples.",
        "Each colored ribbon represents a clonotype, and its height represents its proportion.",
        "",
        "What to look for:",
        "\u2022 Ribbons that flow across multiple samples = 'public' or shared clonotypes, present in both samples.",
        "\u2022 Ribbons that appear in only one sample = 'private' clonotypes, unique to that sample.",
        "\u2022 In longitudinal studies (same patient, different time points), shared clonotypes represent persistent immune memory.",
        "\u2022 In different patients, shared clonotypes suggest convergent immune responses to the same antigen.",
        "\u2022 The height of each ribbon shows how dominant that clone is \u2014 a thick ribbon across both samples means a highly expanded public clone.",
        sep = "\n")
    ),
    Overlap = list(
      short = "Repertoire overlap",
      summary = "Pairwise clonotype sharing between samples. High overlap indicates similar immune responses or active cell trafficking.",
      detail = paste(
        "This heatmap shows pairwise overlap between every combination of samples.",
        "Overlap is calculated as the fraction of clonotypes shared between two samples.",
        "",
        "What to look for:",
        "\u2022 Dark/high values mean two samples share many clonotypes \u2014 their immune responses are similar.",
        "\u2022 Light/low values mean the samples have mostly distinct clonotypes.",
        "\u2022 The diagonal is always maximal (a sample perfectly overlaps with itself).",
        "\u2022 In treatment studies: high overlap between pre- and post-treatment suggests the treatment didn't dramatically reshape the repertoire.",
        "\u2022 In tissue comparisons: high overlap between blood and tumor suggests active immune cell trafficking.",
        "\u2022 Symmetric matrix: overlap(A,B) = overlap(B,A).",
        sep = "\n")
    ),
    Scatter = list(
      short = "Clone frequency scatter",
      summary = "Scatterplot comparing clonotype frequencies between two samples. Off-diagonal clones have expanded or contracted.",
      detail = paste(
        "Each dot is a clonotype. The X-axis shows its frequency in one sample; the Y-axis shows its frequency in another.",
        "",
        "What to look for:",
        "\u2022 Dots on the diagonal: clones equally abundant in both samples (stable clones).",
        "\u2022 Dots above the diagonal: clones expanded in the Y-axis sample relative to the X-axis sample.",
        "\u2022 Dots below the diagonal: clones expanded in the X-axis sample.",
        "\u2022 Dots along the X-axis only (Y near 0): clones found only in the first sample.",
        "\u2022 Dots along the Y-axis only (X near 0): clones found only in the second sample.",
        "\u2022 Larger dots indicate clones with higher total abundance across both samples.",
        "\u2022 This is one of the most intuitive plots for identifying clones that expand or contract between conditions.",
        sep = "\n")
    ),
    SizeDist = list(
      short = "Clone size distribution clustering",
      summary = "Hierarchical clustering of samples by clone size distribution. Samples that cluster together share similar repertoire architecture.",
      detail = paste(
        "This dendrogram clusters samples based on how similar their clone size distributions are.",
        "It uses Ward's hierarchical clustering method \u2014 samples that branch together early have the most similar patterns.",
        "",
        "What to look for:",
        "\u2022 Samples that cluster together share similar 'shapes' of repertoire \u2014 e.g., both dominated by a few big clones, or both having many small clones.",
        "\u2022 If disease samples cluster separately from healthy samples, it suggests disease systematically changes the repertoire structure.",
        "\u2022 If replicates or time points from the same patient cluster together, it confirms biological consistency.",
        "\u2022 Long branch lengths between clusters mean large differences in repertoire structure.",
        "\u2022 This provides a global summary of repertoire 'shape' without focusing on specific clonotypes.",
        sep = "\n")
    )
  )

  ## ---- Collapsible help panel ------------------------------------------- ##
  output$ir_help_panel <- renderUI({
    tab <- input$ir_tabs
    if (is.null(tab)) return(NULL)
    info <- ir_tab_help[[tab]]
    if (is.null(info)) return(NULL)
    div(
      style = "background: #f0f7ff; border-left: 4px solid #3c8dbc; padding: 8px 12px; margin-bottom: 10px; font-size: 13px; border-radius: 2px; display: flex; align-items: flex-start; gap: 10px;",
      div(style = "flex: 1;",
        tags$strong(info$short),
        tags$p(style = "margin: 4px 0 0 0; color: #555;", info$summary)
      ),
      actionButton("ir_help_example_btn",
        label = tags$span(icon("lightbulb"), " Example"),
        class = "btn-xs",
        style = "white-space: nowrap; margin-top: 2px; background: #3c8dbc; color: #fff; border: none;")
    )
  })

  ## ---- Demo data (lazy, cached) ----------------------------------------- ##
  ir_demo_data <- reactiveVal(NULL)

  .get_demo_data <- function() {
    if (!is.null(ir_demo_data())) return(ir_demo_data())
    tryCatch({
      data("contig_list", package = "scRepertoire", envir = environment())
      demo <- scRepertoire::combineTCR(contig_list[1:2],
        samples = c("Healthy", "Disease"))
      ir_demo_data(demo)
      demo
    }, error = function(e) NULL)
  }

  ## ---- Example modal ---------------------------------------------------- ##
  observeEvent(input$ir_help_example_btn, {
    tab <- input$ir_tabs
    if (is.null(tab)) return()
    info <- ir_tab_help[[tab]]
    if (is.null(info)) return()

    showModal(modalDialog(
      title = paste0("Example: ", tab),
      size = "l",
      easyClose = TRUE,
      fade = TRUE,
      div(
        div(style = "font-size: 14px; margin-bottom: 12px;", .format_detail(info$detail)),
        tags$hr(),
        tags$p(style = "color: #888; font-size: 12px;",
          "Generated from scRepertoire built-in demo data (2 TCR samples: Healthy vs Disease)."),
        shinycssloaders::withSpinner(plotOutput("ir_demo_plot", height = "450px"))
      ),
      footer = modalButton("Close")
    ))
  })

  ## ---- Demo plot renderer ----------------------------------------------- ##
  output$ir_demo_plot <- renderPlot({
    tab <- input$ir_tabs
    demo <- .get_demo_data()
    if (is.null(demo) || is.null(tab)) {
      plot.new()
      text(0.5, 0.5, "Demo data unavailable", cex = 1.2)
      return()
    }
    tryCatch({
      p <- switch(tab,
        "Abundance"    = scRepertoire::clonalAbundance(demo, cloneCall = "gene"),
        "Diversity"    = scRepertoire::clonalDiversity(demo, cloneCall = "gene",
                           chain = "TRB", n.boots = 5, palette = "inferno"),
        "Homeostasis"  = scRepertoire::clonalHomeostasis(demo, cloneCall = "gene",
                           chain = "TRB", palette = "inferno"),
        "Length"       = scRepertoire::clonalLength(demo, cloneCall = "aa",
                           chain = "TRB", palette = "inferno"),
        "Proportion"   = scRepertoire::clonalProportion(demo, cloneCall = "gene",
                           chain = "TRB", palette = "inferno"),
        "Quant"        = scRepertoire::clonalQuant(demo, cloneCall = "gene",
                           chain = "TRB", scale = FALSE, palette = "inferno"),
        "Rarefaction"  = scRepertoire::clonalRarefaction(demo, cloneCall = "gene",
                           chain = "TRB", n.boots = 3, palette = "inferno"),
        "Gene usage"   = scRepertoire::percentGeneUsage(demo, chain = "TRB",
                           gene = "TRBV", plot.type = "heatmap", palette = "inferno"),
        "vizGenes"     = scRepertoire::vizGenes(demo,
                           x.axis = "TRBV", y.axis = NULL,
                           plot = "heatmap", palette = "inferno"),
        "percentGenes" = scRepertoire::percentGenes(demo,
                           chain = "TRB", gene = "Vgene", palette = "inferno"),
        "percentVJ"    = scRepertoire::percentVJ(demo,
                           chain = "TRB", palette = "inferno"),
        "AA %"         = scRepertoire::percentAA(demo,
                           chain = "TRB", aa.length = 20, palette = "inferno"),
        "Entropy"      = scRepertoire::positionalEntropy(demo,
                           chain = "TRB", aa.length = 20, palette = "inferno"),
        "Property"     = scRepertoire::positionalProperty(demo,
                           chain = "TRB", method = "atchleyFactors", palette = "inferno"),
        "K-mer"        = scRepertoire::percentKmer(demo,
                           chain = "TRB", cloneCall = "aa",
                           motif.length = 3, top.motifs = 15, palette = "inferno"),
        "Compare"      = scRepertoire::clonalCompare(demo,
                           cloneCall = "gene", chain = "TRB",
                           samples = names(demo), top.clones = 5,
                           graph = "alluvial", palette = "inferno"),
        "Overlap"      = scRepertoire::clonalOverlap(demo,
                           cloneCall = "gene", chain = "TRB",
                           method = "overlap", palette = "inferno"),
        "Scatter"      = scRepertoire::clonalScatter(demo,
                           cloneCall = "gene", chain = "TRB",
                           x.axis = names(demo)[1], y.axis = names(demo)[2],
                           palette = "inferno"),
        "SizeDist"     = scRepertoire::clonalSizeDistribution(demo,
                           cloneCall = "gene", method = "ward.D2"),
        {
          plot.new()
          text(0.5, 0.5, paste("No example available for:", tab), cex = 1.2)
        }
      )
      if (inherits(p, "gg")) print(p)
    }, error = function(e) {
      plot.new()
      text(0.5, 0.5, paste("Error generating example:\n", e$message), cex = 0.9)
    })
  })

  ## ---- Attach tooltips to tab links via JS ------------------------------ ##
  observe({
    tab <- input$ir_tabs
    if (is.null(tab)) return()
    # Build JS to add title attributes to all tab links in ir_tabs
    js_lines <- vapply(names(ir_tab_help), function(name) {
      tip <- ir_tab_help[[name]]$short
      # Escape quotes for JS
      tip <- gsub("'", "\\\\'", tip)
      sprintf(
        "$('#ir_tabs a[data-value=\"%s\"]').attr('title', '%s');",
        name, tip
      )
    }, character(1))
    shinyjs::runjs(paste(js_lines, collapse = "\n"))
  })

  ## ---- Visualizations UI ------------------------------------------------ ##
  output$ir_visualizations_UI <- renderUI({
    req(has_scRepertoire())
    data <- ir_data()
    if (is.null(data)) {
      return(div(class = "alert alert-warning",
        "No immune repertoire data available."))
    }

    ## Always-available tabs
    tabs <- list(
      tabPanel("Abundance",    shinycssloaders::withSpinner(plotOutput("ir_plot_clonalAbundance",          height = 450))),
      tabPanel("Diversity",    shinycssloaders::withSpinner(plotOutput("ir_plot_clonalDiversity",          height = 450))),
      tabPanel("Homeostasis",  shinycssloaders::withSpinner(plotOutput("ir_plot_clonalHomeostasis",        height = 450))),
      tabPanel("Length",       shinycssloaders::withSpinner(plotOutput("ir_plot_clonalLength",             height = 450))),
      tabPanel("Proportion",   shinycssloaders::withSpinner(plotOutput("ir_plot_clonalProportion",         height = 450))),
      tabPanel("Quant",        shinycssloaders::withSpinner(plotOutput("ir_plot_clonalQuant",              height = 450))),
      tabPanel("Rarefaction",  shinycssloaders::withSpinner(uiOutput("ir_ui_clonalRarefaction"))),
      tabPanel("Gene usage",   shinycssloaders::withSpinner(uiOutput("ir_ui_percentGeneUsage"))),
      tabPanel("vizGenes",     shinycssloaders::withSpinner(uiOutput("ir_ui_vizGenes"))),
      tabPanel("percentGenes", shinycssloaders::withSpinner(uiOutput("ir_ui_percentGenes"))),
      tabPanel("percentVJ",    shinycssloaders::withSpinner(uiOutput("ir_ui_percentVJ"))),
      tabPanel("AA %",         shinycssloaders::withSpinner(uiOutput("ir_ui_percentAA"))),
      tabPanel("Entropy",      shinycssloaders::withSpinner(plotOutput("ir_plot_positionalEntropy",        height = 450))),
      tabPanel("Property",     shinycssloaders::withSpinner(uiOutput("ir_ui_positionalProperty"))),
      tabPanel("K-mer",        shinycssloaders::withSpinner(uiOutput("ir_ui_percentKmer")))
    )

    ## Tabs requiring >= 2 samples
    if (n_samples() >= 2) {
      multi_tabs <- list(
        tabPanel("Compare",  shinycssloaders::withSpinner(plotOutput("ir_plot_clonalCompare",              height = 450))),
        tabPanel("Overlap",  shinycssloaders::withSpinner(plotOutput("ir_plot_clonalOverlap",              height = 450))),
        tabPanel("Scatter",  shinycssloaders::withSpinner(plotOutput("ir_plot_clonalScatter",              height = 450))),
        tabPanel("SizeDist", shinycssloaders::withSpinner(plotOutput("ir_plot_clonalSizeDistribution",     height = 450)))
      )
      tabs <- c(tabs, multi_tabs)
    }

    do.call(tabsetPanel, c(list(id = "ir_tabs"), tabs))
  })

  ##------------------------------------------------------------------------##
  ## Plot renderers
  ##------------------------------------------------------------------------##

  output$ir_plot_clonalAbundance <- renderPlot({
    req(has_scRepertoire())
    data <- ir_data(); req(!is.null(data))
    pars <- ir_params()
    safeRenderPlot(
      scRepertoire::clonalAbundance(data, cloneCall = pars$cloneCall,
        group.by = pars$groupBy),
      "clonalAbundance")
  })

  output$ir_plot_clonalCompare <- renderPlot({
    req(has_scRepertoire())
    req(!is.null(input$ir_compare_samples) && length(input$ir_compare_samples) >= 2)
    data <- ir_data(); req(!is.null(data))
    pars <- ir_params()
    safeRenderPlot(
      scRepertoire::clonalCompare(data,
        cloneCall = pars$cloneCall, chain = pars$chain,
        group.by = pars$groupBy, samples = input$ir_compare_samples,
        top.clones = 5, graph = "alluvial", proportion = TRUE,
        exportTable = FALSE, palette = "inferno"),
      "clonalCompare")
  })

  output$ir_plot_clonalDiversity <- renderPlot({
    req(has_scRepertoire())
    data <- ir_data(); req(!is.null(data))
    pars <- ir_params()
    safeRenderPlot(
      scRepertoire::clonalDiversity(data,
        cloneCall = pars$cloneCall, chain = pars$chain,
        group.by = pars$groupBy, metric = "shannon", n.boots = 100,
        exportTable = FALSE, palette = "inferno"),
      "clonalDiversity")
  })

  output$ir_plot_clonalHomeostasis <- renderPlot({
    req(has_scRepertoire())
    data <- ir_data(); req(!is.null(data))
    pars <- ir_params()
    safeRenderPlot(
      scRepertoire::clonalHomeostasis(data,
        cloneCall = pars$cloneCall, chain = pars$chain,
        group.by = pars$groupBy,
        exportTable = FALSE, palette = "inferno"),
      "clonalHomeostasis")
  })

  output$ir_plot_clonalLength <- renderPlot({
    req(has_scRepertoire())
    data <- ir_data(); req(!is.null(data))
    pars <- ir_params()
    safeRenderPlot(
      scRepertoire::clonalLength(data,
        cloneCall = pars$cloneCall, chain = pars$chain,
        group.by = pars$groupBy,
        exportTable = FALSE, palette = "inferno"),
      "clonalLength")
  })

  output$ir_plot_clonalOverlap <- renderPlot({
    req(has_scRepertoire())
    data <- ir_data(); req(!is.null(data))
    pars <- ir_params()
    safeRenderPlot(
      scRepertoire::clonalOverlap(data,
        cloneCall = pars$cloneCall, chain = pars$chain,
        group.by = pars$groupBy, method = "overlap",
        exportTable = FALSE, palette = "inferno"),
      "clonalOverlap")
  })

  output$ir_plot_clonalProportion <- renderPlot({
    req(has_scRepertoire())
    data <- ir_data(); req(!is.null(data))
    pars <- ir_params()
    safeRenderPlot(
      scRepertoire::clonalProportion(data,
        cloneCall = pars$cloneCall, chain = pars$chain,
        group.by = pars$groupBy,
        clonalSplit = c(10, 100, 1000, 10000, 30000, 1e+05),
        exportTable = FALSE, palette = "inferno"),
      "clonalProportion")
  })

  output$ir_plot_clonalQuant <- renderPlot({
    req(has_scRepertoire())
    data <- ir_data(); req(!is.null(data))
    pars <- ir_params()
    safeRenderPlot(
      scRepertoire::clonalQuant(data,
        cloneCall = pars$cloneCall, chain = pars$chain,
        group.by = pars$groupBy, scale = FALSE,
        exportTable = FALSE, palette = "inferno"),
      "clonalQuant")
  })

  output$ir_ui_clonalRarefaction <- renderUI({
    n_boots <- input$ir_rarefaction_boots
    if (is.null(n_boots)) n_boots <- 5
    tagList(
      sliderInput("ir_rarefaction_boots", "Bootstrap iterations:",
        min = 3, max = 50, value = n_boots, step = 1),
      shinycssloaders::withSpinner(plotOutput("ir_plot_clonalRarefaction", height = "450px"))
    )
  })

  output$ir_plot_clonalRarefaction <- renderPlot({
    req(has_scRepertoire())
    data <- ir_data(); req(!is.null(data))
    pars <- ir_params()
    n_boots <- input$ir_rarefaction_boots
    if (is.null(n_boots)) n_boots <- 5
    safeRenderPlot(
      scRepertoire::clonalRarefaction(data,
        cloneCall = pars$cloneCall, chain = pars$chain,
        group.by = pars$groupBy,
        plot.type = 1, hill.numbers = 0, n.boots = n_boots,
        exportTable = FALSE, palette = "inferno"),
      "clonalRarefaction")
  })

  output$ir_plot_clonalScatter <- renderPlot({
    req(has_scRepertoire())
    req(!is.null(input$ir_scatter_x) && !is.null(input$ir_scatter_y))
    data <- ir_data(); req(!is.null(data))
    pars <- ir_params()
    safeRenderPlot(
      scRepertoire::clonalScatter(data,
        cloneCall = pars$cloneCall, chain = pars$chain,
        group.by = pars$groupBy,
        x.axis = input$ir_scatter_x, y.axis = input$ir_scatter_y,
        dot.size = "total", graph = "proportion",
        exportTable = FALSE, palette = "inferno"),
      "clonalScatter")
  })

  output$ir_plot_clonalSizeDistribution <- renderPlot({
    req(has_scRepertoire())
    data <- ir_data(); req(!is.null(data))
    pars <- ir_params()
    safeRenderPlot(
      scRepertoire::clonalSizeDistribution(data,
        cloneCall = pars$cloneCall, group.by = pars$groupBy,
        method = "ward.D2",
        exportTable = FALSE),
      "clonalSizeDistribution")
  })

  output$ir_ui_percentGeneUsage <- renderUI({
    h <- ir_plot_height("none")
    shinycssloaders::withSpinner(plotOutput("ir_plot_percentGeneUsage", height = paste0(h, "px")))
  })

  output$ir_plot_percentGeneUsage <- renderPlot({
    req(has_scRepertoire())
    data <- ir_data(); req(!is.null(data))
    pars <- ir_params()
    safeRenderPlot(
      scRepertoire::percentGeneUsage(data,
        chain = pars$chain, gene = default_gene_family(),
        group.by = pars$groupBy,
        summary.fun = "percent", plot.type = "heatmap",
        exportTable = FALSE, palette = "inferno"),
      "percentGeneUsage")
  })

  output$ir_ui_vizGenes <- renderUI({
    h <- ir_plot_height("none")
    shinycssloaders::withSpinner(plotOutput("ir_plot_vizGenes", height = paste0(h, "px")))
  })

  output$ir_plot_vizGenes <- renderPlot({
    req(has_scRepertoire())
    data <- ir_data(); req(!is.null(data))
    pars <- ir_params()
    safeRenderPlot(
      scRepertoire::vizGenes(data,
        x.axis = default_gene_family(), y.axis = NULL,
        group.by = pars$groupBy,
        plot = "heatmap", summary.fun = "count",
        exportTable = FALSE, palette = "inferno"),
      "vizGenes")
  })

  output$ir_ui_percentGenes <- renderUI({
    h <- ir_plot_height("none")
    shinycssloaders::withSpinner(plotOutput("ir_plot_percentGenes", height = paste0(h, "px")))
  })

  output$ir_plot_percentGenes <- renderPlot({
    req(has_scRepertoire())
    data <- ir_data(); req(!is.null(data))
    pars <- ir_params()
    safeRenderPlot(
      scRepertoire::percentGenes(data,
        chain = specific_chain(), gene = "Vgene",
        group.by = pars$groupBy, summary.fun = "percent",
        exportTable = FALSE, palette = "inferno"),
      "percentGenes")
  })

  output$ir_ui_percentVJ <- renderUI({
    h <- ir_plot_height("wrap")
    shinycssloaders::withSpinner(plotOutput("ir_plot_percentVJ", height = paste0(h, "px")))
  })

  output$ir_plot_percentVJ <- renderPlot({
    req(has_scRepertoire())
    data <- ir_data(); req(!is.null(data))
    pars <- ir_params()
    safeRenderPlot(
      scRepertoire::percentVJ(data,
        chain = specific_chain(),
        group.by = pars$groupBy, summary.fun = "percent",
        exportTable = FALSE, palette = "inferno"),
      "percentVJ")
  })

  output$ir_ui_percentAA <- renderUI({
    ng <- n_groups()
    # facet_grid(group ~ .): ~200px per group, minimum 400
    h <- max(400, ng * 200)
    shinycssloaders::withSpinner(plotOutput("ir_plot_percentAA", height = paste0(h, "px")))
  })

  output$ir_plot_percentAA <- renderPlot({
    req(has_scRepertoire())
    data <- ir_data(); req(!is.null(data))
    pars <- ir_params()
    safeRenderPlot(
      scRepertoire::percentAA(data,
        chain = pars$chain, group.by = pars$groupBy,
        aa.length = 20,
        exportTable = FALSE, palette = "inferno"),
      "percentAA")
  })

  output$ir_plot_positionalEntropy <- renderPlot({
    req(has_scRepertoire())
    data <- ir_data(); req(!is.null(data))
    pars <- ir_params()
    safeRenderPlot(
      scRepertoire::positionalEntropy(data,
        chain = pars$chain, group.by = pars$groupBy,
        aa.length = 20, method = "norm.entropy",
        exportTable = FALSE, palette = "inferno"),
      "positionalEntropy")
  })

  ## ---- Positional Property: facet count per method ---------------------- ##
  ## Requires immApex; most methods also need the Peptides package.
  all_property_facets <- c(
    atchleyFactors = 5, crucianiProperties = 3, FASGAI = 6,
    kideraFactors = 10, MSWHIM = 3, ProtFP = 8,
    stScales = 8, tScales = 5, VHSE = 8, zScales = 5
  )

  available_property_methods <- reactive({
    resolver <- tryCatch(
      getFromNamespace(".aa.property.matrix", "immApex"),
      error = function(e) NULL)
    if (is.null(resolver)) return(all_property_facets["atchleyFactors"])
    ok <- vapply(names(all_property_facets), function(m) {
      tryCatch({ resolver(m); TRUE }, error = function(e) FALSE)
    }, logical(1))
    all_property_facets[ok]
  })

  output$ir_ui_positionalProperty <- renderUI({
    avail <- available_property_methods()
    method <- input$ir_property_method
    if (is.null(method) || !method %in% names(avail)) method <- names(avail)[1]
    n_facets <- avail[[method]]
    if (is.null(n_facets)) n_facets <- 5
    # ~120px per facet row, minimum 450
    h <- max(450, n_facets * 120)
    tagList(
      selectInput("ir_property_method", "Property method:",
        choices = names(avail), selected = method),
      shinycssloaders::withSpinner(plotOutput("ir_plot_positionalProperty", height = paste0(h, "px")))
    )
  })

  output$ir_plot_positionalProperty <- renderPlot({
    req(has_scRepertoire())
    data <- ir_data(); req(!is.null(data))
    pars <- ir_params()
    method <- input$ir_property_method
    if (is.null(method)) method <- "atchleyFactors"
    safeRenderPlot(
      scRepertoire::positionalProperty(data,
        chain = pars$chain, group.by = pars$groupBy,
        method = method,
        exportTable = FALSE, palette = "inferno"),
      "positionalProperty")
  })

  output$ir_ui_percentKmer <- renderUI({
    top_m <- input$ir_kmer_top_motifs
    if (is.null(top_m)) top_m <- 30
    h <- max(450, top_m * 20)
    tagList(
      sliderInput("ir_kmer_top_motifs", "Top motifs:",
        min = 10, max = 100, value = top_m, step = 5),
      shinycssloaders::withSpinner(plotOutput("ir_plot_percentKmer", height = paste0(h, "px")))
    )
  })

  output$ir_plot_percentKmer <- renderPlot({
    req(has_scRepertoire())
    data <- ir_data(); req(!is.null(data))
    pars <- ir_params()
    top_m <- input$ir_kmer_top_motifs
    if (is.null(top_m)) top_m <- 30
    safeRenderPlot(
      scRepertoire::percentKmer(data,
        chain = pars$chain, cloneCall = pars$cloneCall,
        group.by = pars$groupBy,
        motif.length = 3, min.depth = 3, top.motifs = top_m,
        exportTable = FALSE, palette = "inferno"),
      "percentKmer")
  })

})
