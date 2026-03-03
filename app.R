library(shiny)
library(dplyr)
library(terra)
library(DT)
library(leaflet)

# ============================================================
# UI
# ============================================================
ui <- fluidPage(
  titlePanel("Climate Data Extraction Tool"),
  
  tags$head(
    tags$style(HTML("
      .content { padding: 20px; }
      .section-box { 
        background-color: #f8f9fa; 
        padding: 20px; 
        border-radius: 5px; 
        border: 1px solid #ddd;
        margin-bottom: 20px;
      }
      .btn-lg { font-size: 16px; padding: 10px; 20px; }
      .alert { padding: 15px; margin-top: 15px; border-radius: 5px; }
      .alert-success { background-color: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
      .alert-info { background-color: #d1ecf1; color: #0c5460; border: 1px solid #bee5eb; }
      .alert-warning { background-color: #fff3cd; color: #856404; border: 1px solid #ffeaa7; }
      .alert-danger { background-color: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }
      .map-container { height: 400px; margin-top: 20px; }
    "))
  ),
  
  div(class = "content",
    # Step 1: Coordinate Input
    div(class = "section-box",
      h3("Step 1: Provide Coordinates"),
      
      radioButtons(
        "input_method",
        "How would you like to provide coordinates?",
        choices = c(
          "Enter manually" = "manual",
          "Upload CSV file" = "upload"
        ),
        selected = "manual"
      ),
      
      # Manual entry panel
      conditionalPanel(
        condition = "input.input_method == 'manual'",
        fluidRow(
          column(5, numericInput("latitude", "Latitude:", value = NULL, min = -90, max = 90, step = 0.00001)),
          column(5, numericInput("longitude", "Longitude:", value = NULL, min = -180, max = 180, step = 0.00001)),
          column(2, br(), actionButton("add_coord", "Add", icon = icon("plus"), class = "btn-success"))
        ),
        br(),
        actionButton("clear_all", "Clear All", icon = icon("trash"), class = "btn-warning btn-sm")
      ),
      
      # File upload panel
      conditionalPanel(
        condition = "input.input_method == 'upload'",
        fileInput("coords_file", "Upload CSV File", accept = ".csv"),
        p(class = "text-muted", "CSV must contain columns starting with 'lat' and 'lon'. All columns from your file will be preserved in the output.")
      ),
      
      br(),
      h5("Coordinates Table:"),
      DTOutput("coords_table"),
      uiOutput("coord_count")
    ),
    
    # Step 2: Select Time Period and Scenario
    div(class = "section-box",
      h3("Step 2: Select Climate Data"),
      
      fluidRow(
        column(6,
          selectInput(
            "time_period",
            "Select Time Period:",
            choices = c(
              "Historical (1981-2024)" = "1981_2024",
              "Near Future (2021-2040)" = "2021_2040",
              "Mid Future (2041-2060)" = "2041_2060",
              "Late Future (2061-2080)" = "2061_2080",
              "End Century (2081-2100)" = "2081_2100"
            ),
            selected = "2021_2040"
          )
        ),
        column(6,
          uiOutput("model_selector")
        )
      ),
      
      # SSP Scenario selection (only for future data)
      conditionalPanel(
        condition = "input.time_period != '1981_2024'",
        selectInput(
          "scenario",
          "Select Climate Scenario (SSP):",
          choices = c(
            "SSP1-2.6 (Low emissions)" = "ssp126",
            "SSP2-4.5 (Medium emissions)" = "ssp245",
            "SSP3-7.0 (High emissions)" = "ssp370",
            "SSP5-8.5 (Very high emissions)" = "ssp585"
          ),
          selected = "ssp245"
        )
      ),
      
      # Info message for historical data
      conditionalPanel(
        condition = "input.time_period == '1981_2024'",
        div(class = "alert alert-info", 
            icon("info-circle"), 
            " Historical data (1981-2024) is only available for EC-Earth3-Veg model.")
      )
    ),
    
    # Step 3: Extract Data
    div(class = "section-box",
      h3("Step 3: Extract Bioclimatic Variables"),
      actionButton("extract", "Extract Bio Variables", 
                   class = "btn-primary btn-lg", 
                   icon = icon("download")),
      uiOutput("status_message")
    ),
    
    # Step 4: Preview and Download with Map
    conditionalPanel(
      condition = "output.show_results",
      div(class = "section-box",
        h3("Step 4: Review and Download Results"),
        
        # Map visualization
        h5("Location Map:"),
        div(class = "map-container",
          leafletOutput("location_map", height = "100%")
        ),
        
        br(),
        h5("Data Preview:"),
        DTOutput("preview_table"),
        br(),
        downloadButton("download_data", "Download CSV", class = "btn-success btn-lg", icon = icon("file-download"))
      )
    )
  )
)

# ============================================================
# SERVER
# ============================================================
server <- function(input, output, session) {
  
  # Reactive values
  coords_data    <- reactiveVal(data.frame(latitude = numeric(), longitude = numeric()))
  extracted_data <- reactiveVal(NULL)
  original_data  <- reactiveVal(NULL)
  has_user_id    <- reactiveVal(FALSE)
  
  # Dynamic model selector based on time period
  output$model_selector <- renderUI({
    time_period <- input$time_period
    
    if(time_period == "1981_2024") {
      selectInput(
        "model",
        "Select Model:",
        choices  = c("EC-Earth3-Veg" = "EC-Earth3-Veg"),
        selected = "EC-Earth3-Veg"
      )
    } else {
      selectInput(
        "model",
        "Select Model:",
        choices  = c(
          "EC-Earth3-Veg" = "EC-Earth3-Veg",
          "ACCESS-CM2"    = "ACCESS-CM2"
        ),
        selected = "EC-Earth3-Veg"
      )
    }
  })
  
  # Add coordinate manually
  observeEvent(input$add_coord, {
    lat <- input$latitude
    lon <- input$longitude
    
    if(is.na(lat) || is.na(lon)) {
      showNotification("Please enter valid latitude and longitude values", type = "error")
      return()
    }
    if(lat < -90 || lat > 90) {
      showNotification("Latitude must be between -90 and 90", type = "error")
      return()
    }
    if(lon < -180 || lon > 180) {
      showNotification("Longitude must be between -180 and 180", type = "error")
      return()
    }
    
    coords_data(rbind(coords_data(), data.frame(latitude = lat, longitude = lon)))
    original_data(NULL)
    has_user_id(FALSE)
    updateNumericInput(session, "latitude",  value = NA)
    updateNumericInput(session, "longitude", value = NA)
    showNotification("Coordinate added successfully", type = "message")
  })
  
  # Clear all coordinates
  observeEvent(input$clear_all, {
    coords_data(data.frame(latitude = numeric(), longitude = numeric()))
    original_data(NULL)
    has_user_id(FALSE)
    showNotification("All coordinates cleared", type = "message")
  })
  
  # Handle file upload
  observe({
    req(input$input_method == "upload")
    req(input$coords_file)
    
    tryCatch({
      data <- read.csv(input$coords_file$datapath, stringsAsFactors = FALSE)
      
      lat_cols      <- grep("^lat",      names(data), ignore.case = TRUE, value = TRUE)
      lon_cols      <- grep("^lon",      names(data), ignore.case = TRUE, value = TRUE)
      id_cols       <- grep("^id$",      names(data), ignore.case = TRUE, value = TRUE)
      location_cols <- grep("^location$",names(data), ignore.case = TRUE, value = TRUE)
      
      if(length(lat_cols) == 0) {
        showNotification("CSV must contain a column starting with 'lat'", type = "error")
        return()
      }
      if(length(lon_cols) == 0) {
        showNotification("CSV must contain a column starting with 'lon'", type = "error")
        return()
      }
      
      lat_col <- lat_cols[1]
      lon_col <- lon_cols[1]
      
      user_has_id <- length(id_cols) > 0 || length(location_cols) > 0
      has_user_id(user_has_id)
      
      coords <- data.frame(
        latitude  = data[[lat_col]],
        longitude = data[[lon_col]]
      )
      
      valid_rows <- complete.cases(coords)
      coords     <- coords[valid_rows, ]
      original_data(data[valid_rows, ])
      
      if(nrow(coords) == 0) {
        showNotification("No valid coordinates found in the file", type = "error")
        return()
      }
      if(any(coords$latitude < -90 | coords$latitude > 90, na.rm = TRUE)) {
        showNotification("Some latitude values are out of range (-90 to 90)", type = "error")
        return()
      }
      if(any(coords$longitude < -180 | coords$longitude > 180, na.rm = TRUE)) {
        showNotification("Some longitude values are out of range (-180 to 180)", type = "error")
        return()
      }
      
      coords_data(coords)
      
      id_msg <- if(user_has_id) {
        " All original columns including ID/Location will be preserved."
      } else {
        " An ID column will be added to the output."
      }
      showNotification(
        paste0("File uploaded successfully! Found ", nrow(coords),
               " coordinates using columns: '", lat_col, "' and '", lon_col, "'.", id_msg),
        type = "message", duration = 5
      )
      
    }, error = function(e) {
      showNotification(paste("Error reading file:", e$message), type = "error")
    })
  })
  
  # Display coordinates table
  output$coords_table <- renderDT({
    df <- coords_data()
    req(nrow(df) > 0)
    display_df <- if(!is.null(original_data())) original_data() else df
    datatable(display_df,
              options = list(pageLength = 10, scrollX = TRUE, dom = 'tp'),
              rownames = FALSE)
  })
  
  # Coordinate count
  output$coord_count <- renderUI({
    count <- nrow(coords_data())
    if(count == 0) {
      div(class = "alert alert-warning", icon("info-circle"), " No coordinates added yet")
    } else {
      div(class = "alert alert-info", icon("check-circle"),
          sprintf(" %d coordinate%s ready for extraction", count, ifelse(count > 1, "s", "")))
    }
  })
  
  # ── Extract bioclimatic variables ─────────────────────────
  observeEvent(input$extract, {
    coords <- coords_data()
    
    if(nrow(coords) == 0) {
      showNotification("Please add coordinates first", type = "error")
      return()
    }
    
    model       <- input$model
    time_period <- input$time_period
    
    if(is.null(model) || model == "") {
      showNotification("Please select a model", type = "error")
      return()
    }
    
    output$status_message <- renderUI({
      div(class = "alert alert-info", icon("spinner", class = "fa-spin"), " Processing and Cleaning Data...")
    })
    
    withProgress(message = 'Extracting and Sanitizing Data...', value = 0, {
      tryCatch({
        
        # 1. Build SpatVector from ALL original coordinates
        pts <- terra::vect(coords, geom = c("longitude", "latitude"), crs = "EPSG:4326")
        
        # 2. Extract bio variables
        if(time_period == "1981_2024") {
          
          folder_path <- file.path("data", model, paste0("WorldClim_Data_", time_period))
          bio_values  <- data.frame(matrix(ncol = 19, nrow = nrow(coords)))
          names(bio_values) <- paste0("bio", 1:19)
          
          for(i in 1:19) {
            incProgress(0.04, detail = paste("Extracting bio", i))
            bio_file <- list.files(folder_path,
                                   pattern    = paste0("^BIO", i, "_WORLD.*\\.tif$"),
                                   full.names = TRUE, ignore.case = TRUE)
            if(length(bio_file) > 0) {
              r <- terra::rast(bio_file[1])
              bio_values[, i] <- terra::extract(r, pts)[, 2]
            }
          }
          
        } else {
          
          scenario           <- input$scenario
          folder_path        <- file.path("data", model, paste0("WorldClim_Data_", time_period))
          period_with_hyphen <- gsub("_", "-", time_period)
          file_pattern       <- paste0("wc2.1_5m_bioc_", model, "_", scenario,
                                       "_", period_with_hyphen, "\\.tif$")
          
          raster_file <- list.files(folder_path, pattern = file_pattern, full.names = TRUE)
          if(length(raster_file) == 0) stop("Climate raster file not found on server.")
          
          r          <- terra::rast(raster_file[1])
          bio_values <- terra::extract(r, pts)[, -1]
          names(bio_values) <- paste0("bio", 1:ncol(bio_values))
        }
        
        # 3. Merge bio values with coordinate metadata
        if(!is.null(original_data())) {
          combined_df <- cbind(original_data(), bio_values)
        } else {
          combined_df <- cbind(
            id  = paste0("Site_", 1:nrow(coords)),
            lat = coords$latitude,
            lon = coords$longitude,
            bio_values
          )
        }
        
        # 4. Sanitise headers
        names(combined_df) <- make.names(names(combined_df), unique = TRUE)
        names(combined_df) <- gsub("\\.", "_", names(combined_df))
        names(combined_df) <- gsub("__+", "_", names(combined_df))
        
        # Standardise coordinate column names to lat / lon
        names(combined_df) <- gsub("^latitude$",  "lat", names(combined_df))
        names(combined_df) <- gsub("^longitude$", "lon", names(combined_df))
        
        # 5. Force UTF-8 encoding
        combined_df <- as.data.frame(lapply(combined_df, function(x) {
          if(is.character(x)) iconv(x, to = "UTF-8", sub = "byte") else x
        }))
        
        # 6. Drop ocean / out-of-extent rows based on bio NAs
        #    *** Must happen BEFORE elevation extraction ***
        #    so that pts_filtered and final_df always have the same row count
        bio_cols   <- grep("^bio",    names(combined_df), ignore.case = TRUE, value = TRUE)
        coord_cols <- grep("lat|lon", names(combined_df), ignore.case = TRUE, value = TRUE)
        
        initial_rows  <- nrow(combined_df)
        valid_indices <- complete.cases(combined_df[, c(coord_cols, bio_cols)])
        final_df      <- combined_df[valid_indices, ]
        rows_dropped  <- initial_rows - nrow(final_df)
        
        if(nrow(final_df) == 0) {
          stop("Extraction resulted in 0 rows. All coordinates are likely in the ocean or outside the climate map extent.")
        }
        
        # 7. Extract elevation from the filtered points only
        #    Row count of pts_filtered == nrow(final_df) — no mismatch possible
        incProgress(0.05, detail = "Extracting elevation...")
        
        lon_col_name <- coord_cols[grep("^lon", coord_cols, ignore.case = TRUE)[1]]
        lat_col_name <- coord_cols[grep("^lat", coord_cols, ignore.case = TRUE)[1]]
        
        pts_filtered <- terra::vect(
          data.frame(
            lon = final_df[[lon_col_name]],
            lat = final_df[[lat_col_name]]
          ),
          geom = c("lon", "lat"),
          crs  = "EPSG:4326"
        )
        
        elev_file <- file.path("data", "wc2.1_30s_elev.tif")
        if(file.exists(elev_file)) {
          elev_rast          <- terra::rast(elev_file)
          final_df$elevation <- terra::extract(elev_rast, pts_filtered)[, 2]
        } else {
          final_df$elevation <- NA_real_
        }
        
        # 8. Reorder columns: id-like → lat → lon → elevation → bio1 … bio19
        bio_ordered     <- bio_cols[order(as.numeric(gsub("[^0-9]", "", bio_cols)))]
        id_like_cols    <- setdiff(names(final_df), c("lat", "lon", "elevation", bio_ordered))
        final_col_order <- intersect(
          c(id_like_cols, "lat", "lon", "elevation", bio_ordered),
          names(final_df)
        )
        final_df <- final_df[, final_col_order]
        
        extracted_data(final_df)
        
        # 9. Success message — no popup warnings, everything inline
        output$status_message <- renderUI({
          div(class = "alert alert-success",
              icon("check-circle"),
              strong(" Extraction Complete! "),
              p(sprintf("Processed %d locations successfully.", nrow(final_df))),
              if(rows_dropped > 0)
                p(sprintf(
                  "Note: %d rows were removed as they returned no climate data — these points are likely in the ocean or outside the raster extent.",
                  rows_dropped
                ))
          )
        })
        
      }, error = function(e) {
        output$status_message <- renderUI({
          div(class = "alert alert-danger",
              icon("exclamation-triangle"), strong(" Error: "), e$message)
        })
      })
    })
  })
  
  # Control results display
  output$show_results <- reactive({ !is.null(extracted_data()) })
  outputOptions(output, "show_results", suspendWhenHidden = FALSE)
  
  # Location map
  output$location_map <- renderLeaflet({
    req(extracted_data())
    data <- extracted_data()
    
    data$has_data <- !is.na(data$bio1)
    
    pal <- colorFactor(palette = c("red", "green"), domain = c(FALSE, TRUE))
    
    id_col <- if("id"       %in% names(data)) "id"
              else if("location" %in% names(data)) "location"
              else NULL
    
    popup_text <- if(!is.null(id_col)) {
      paste0(
        "<strong>", id_col, ":</strong> ", data[[id_col]], "<br>",
        "<strong>Lat:</strong> ",       round(data$lat, 4), "<br>",
        "<strong>Lon:</strong> ",       round(data$lon, 4), "<br>",
        "<strong>Elevation:</strong> ", round(data$elevation, 1), " m<br>",
        "<strong>Data:</strong> ",      ifelse(data$has_data, "✓ Extracted", "✗ No data")
      )
    } else {
      paste0(
        "<strong>Lat:</strong> ",       round(data$lat, 4), "<br>",
        "<strong>Lon:</strong> ",       round(data$lon, 4), "<br>",
        "<strong>Elevation:</strong> ", round(data$elevation, 1), " m<br>",
        "<strong>Data:</strong> ",      ifelse(data$has_data, "✓ Extracted", "✗ No data")
      )
    }
    
    leaflet(data) %>%
      addTiles() %>%
      addCircleMarkers(
        lng         = ~lon,
        lat         = ~lat,
        radius      = 6,
        color       = ~pal(has_data),
        fillOpacity = 0.8,
        stroke      = TRUE,
        weight      = 2,
        popup       = popup_text
      ) %>%
      addLegend(
        position = "bottomright",
        colors   = c("green", "red"),
        labels   = c("Data extracted", "No data (ocean/water)"),
        title    = "Extraction Status"
      ) %>%
      fitBounds(
        lng1 = min(data$lon) - 1, lat1 = min(data$lat) - 1,
        lng2 = max(data$lon) + 1, lat2 = max(data$lat) + 1
      )
  })
  
  # Preview table
  output$preview_table <- renderDT({
    req(extracted_data())
    datatable(
      extracted_data(),
      options  = list(pageLength = 10, scrollX = TRUE, dom = 'tip'),
      rownames = FALSE
    ) %>%
      formatRound(columns = grep("^bio", names(extracted_data()), value = TRUE), digits = 2)
  })
  
  # Download handler
  output$download_data <- downloadHandler(
    filename = function() {
      time_label <- gsub("_", "-", input$time_period)
      model_name <- if(input$time_period == "1981_2024") "Historical" else input$model
      paste0("Climate_Ready_", model_name, "_", time_label, "_", Sys.Date(), ".csv")
    },
    content = function(file) {
      final_output        <- extracted_data()
      names(final_output) <- trimws(names(final_output))
      con <- file(file, open = "wt", encoding = "UTF-8")
      write.csv(final_output, con, row.names = FALSE, na = "")
      close(con)
    }
  )
}

# ============================================================
# RUN APP
# ============================================================
shinyApp(ui, server)