##----------------------------------------------------------------------------##
## Sample info.
##----------------------------------------------------------------------------##

##----------------------------------------------------------------------------##
## UI elements that show some basic information about the loaded data set.
##----------------------------------------------------------------------------##
#
output[["load_data_sample_info_UI"]] <- renderUI({
  tagList(
    h3("Sample information"),
    ## Three stat cards laid out in one row (4/4/4 of the 12-col grid); each
    ## valueBoxOutput's own width is cleared so the enclosing column controls it.
    ## Columns stack automatically on narrow screens.
    fluidRow(
      column(
        width = 4,
        valueBoxOutput("load_data_number_of_cells", width = NULL)
      ),
      column(width = 4, valueBoxOutput("load_data_organism", width = NULL)),
      column(
        width = 4,
        valueBoxOutput("load_data_date_of_export", width = NULL)
      )
    )
  )
})

##----------------------------------------------------------------------------##
## Value boxes that show:
## - number of observations (cells, unless the data set declares otherwise)
## - organism
## - date of export
##----------------------------------------------------------------------------##

##number of observations. Named from the data set's declared observation unit
##(see getObservationUnit): a bulk repertoire data set's rows are analysis
##units, not cells, and labelling them "Cells" would state a measurement that
##was never made. Single-cell data — every existing .crb — still says "Cells".
output[["load_data_number_of_cells"]] <- renderValueBox({
  valueBox(
    value = formatC(
      nrow(data_set()$meta_data),
      format = "f",
      big.mark = ",",
      digits = 0
    ),
    subtitle = getObservationUnit()$title,
    color = "light-blue",
    icon = icon("list"),
  )
})

## organism
output[["load_data_organism"]] <- renderValueBox({
  if (getExperiment()$organism == "hg") {
    valueBox(
      value = ifelse(
        !is.null(getExperiment()$organism),
        getExperiment()$organism,
        "not available"
      ),
      subtitle = "Organism",
      color = "yellow",
      icon = icon("user")
    )
  } else {
    valueBox(
      value = ifelse(
        !is.null(getExperiment()$organism),
        getExperiment()$organism,
        "not available"
      ),
      subtitle = "Organism",
      color = "yellow",
      icon = icon("paw")
    )
  }
})

## date of export
## as.character() because the date is otherwise converted to interger
output[["load_data_date_of_export"]] <- renderValueBox({
  valueBox(
    value = ifelse(
      !is.null(getExperiment()$date_of_export),
      as.character(getExperiment()$date_of_export),
      "not available"
    ),
    subtitle = "Date",
    color = "green",
    icon = icon("calendar-day")
  )
})
