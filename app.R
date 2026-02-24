library(shiny)
library(dplyr)
library(terra)
library(DT)

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
      .btn-lg { font-size: 16px; padding: 10px 20px; }
      .alert { padding: 15px; margin-top: 15px; border-radius: 5px; }
      .alert-success { background-color: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
      .alert-info { background-color: #d1ecf1; color: #0c5460; border: 1px solid #bee5eb; }
      .alert-warning { background-color: #fff3cd; color: #856404; border: 1px solid #ffeaa7; }
      .alert-danger { background-color: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }
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
        p(class = "text-muted", "CSV must contain columns starting with 'lat' and 'lon' (e.g., latitude, lat, longitude, lon, lat_deg, lon_deg, etc.)")
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
          selectInput(
            "model",
            "Select Model:",
            choices = c("EC-Earth3-Veg" = "EC-Earth3-Veg"),
            selected = "EC-Earth3-Veg"
          )
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
            " Historical data (1981-2024) will use individual bio variable files.")
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
    
    # Step 4: Preview and Download
    conditionalPanel(
      condition = "output.show_results",
      div(class = "section-box",
        h3("Step 4: Download Results"),
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
  coords_data <- reactiveVal(data.frame(latitude = numeric(), longitude = numeric()))
  extracted_data <- reactiveVal(NULL)
  
  # Add coordinate manually
  observeEvent(input$add_coord, {
    lat <- input$latitude
    lon <- input$longitude
    
    # Validation
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
    
    # Add to table
    new_row <- data.frame(latitude = lat, longitude = lon)
    coords_data(rbind(coords_data(), new_row))
    
    # Reset inputs
    updateNumericInput(session, "latitude", value = NA)
    updateNumericInput(session, "longitude", value = NA)
    
    showNotification("Coordinate added successfully", type = "message")
  })
  
  # Clear all coordinates
  observeEvent(input$clear_all, {
    coords_data(data.frame(latitude = numeric(), longitude = numeric()))
    showNotification("All coordinates cleared", type = "message")
  })
  
  # Handle file upload with flexible column name matching
  observe({
    req(input$input_method == "upload")
    req(input$coords_file)
    
    tryCatch({
      data <- read.csv(input$coords_file$datapath, stringsAsFactors = FALSE)
      
      # Find columns that start with "lat" (case insensitive)
      lat_cols <- grep("^lat", names(data), ignore.case = TRUE, value = TRUE)
      
      # Find columns that start with "lon" (case insensitive)
      lon_cols <- grep("^lon", names(data), ignore.case = TRUE, value = TRUE)
      
      # Validation
      if(length(lat_cols) == 0) {
        showNotification("CSV must contain a column starting with 'lat' (e.g., latitude, lat, lat_deg)", type = "error")
        return()
      }
      
      if(length(lon_cols) == 0) {
        showNotification("CSV must contain a column starting with 'lon' (e.g., longitude, lon, lon_deg)", type = "error")
        return()
      }
      
      # Use the first matching column for each
      lat_col <- lat_cols[1]
      lon_col <- lon_cols[1]
      
      # Extract only the latitude and longitude columns and rename them
      coords <- data.frame(
        latitude = data[[lat_col]],
        longitude = data[[lon_col]]
      )
      
      # Remove any rows with NA values
      coords <- coords[complete.cases(coords), ]
      
      if(nrow(coords) == 0) {
        showNotification("No valid coordinates found in the file", type = "error")
        return()
      }
      
      # Validate ranges
      if(any(coords$latitude < -90 | coords$latitude > 90, na.rm = TRUE)) {
        showNotification("Some latitude values are out of range (-90 to 90)", type = "error")
        return()
      }
      
      if(any(coords$longitude < -180 | coords$longitude > 180, na.rm = TRUE)) {
        showNotification("Some longitude values are out of range (-180 to 180)", type = "error")
        return()
      }
      
      coords_data(coords)
      showNotification(
        paste0("File uploaded successfully! Found ", nrow(coords), " coordinates using columns: '", 
               lat_col, "' and '", lon_col, "'"), 
        type = "message",
        duration = 5
      )
      
    }, error = function(e) {
      showNotification(paste("Error reading file:", e$message), type = "error")
    })
  })
  
  # Display coordinates table
  output$coords_table <- renderDT({
    df <- coords_data()
    req(nrow(df) > 0)
    
    datatable(
      df,
      options = list(
        pageLength = 10,
        scrollX = TRUE,
        dom = 'tp'
      ),
      rownames = TRUE
    )
  })
  
  # Coordinate count display
  output$coord_count <- renderUI({
    count <- nrow(coords_data())
    if(count == 0) {
      div(class = "alert alert-warning", icon("info-circle"), " No coordinates added yet")
    } else {
      div(class = "alert alert-info", icon("check-circle"), 
          sprintf(" %d coordinate%s ready for extraction", count, ifelse(count > 1, "s", "")))
    }
  })
  
  # Extract bioclimatic variables
  observeEvent(input$extract, {
    coords <- coords_data()
    
    if(nrow(coords) == 0) {
      showNotification("Please add coordinates first", type = "error")
      return()
    }
    
    time_period <- input$time_period
    model <- input$model
    
    output$status_message <- renderUI({
      div(class = "alert alert-info", 
          icon("spinner", class = "fa-spin"), 
          " Extracting data... Please wait...")
    })
    
    withProgress(message = 'Extracting bioclimatic variables...', value = 0, {
      tryCatch({
        
        # Convert coordinates to terra vector
        pts <- terra::vect(coords, geom = c("longitude", "latitude"), crs = "EPSG:4326")
        
        # Different handling for historical vs future data
        if(time_period == "1981_2024") {
          # Historical data: 19 separate files with pattern BIO1_WORLD, BIO2_WORLD, etc.
          incProgress(0.1, detail = "Loading historical data files...")
          
          folder_path <- file.path("data", paste0("WorldClim_Data_", time_period))
          
          if(!dir.exists(folder_path)) {
            stop(paste("Folder not found:", folder_path))
          }
          
          # Initialize result dataframe
          bio_values <- data.frame(matrix(ncol = 19, nrow = nrow(coords)))
          names(bio_values) <- paste0("bio", 1:19)
          
          # Extract from each bio file
          for(i in 1:19) {
            incProgress(0.04, detail = paste("Extracting bio", i, "..."))
            
            # File pattern for historical data: BIO1_WORLD, BIO2_WORLD, etc.
            bio_file <- list.files(
              folder_path, 
              pattern = paste0("^BIO", i, "_WORLD.*\\.tif$"),
              full.names = TRUE,
              ignore.case = TRUE
            )
            
            if(length(bio_file) == 0) {
              warning(paste("File not found for bio", i))
              bio_values[, i] <- NA
              next
            }
            
            # Use first matching file if multiple found
            r <- terra::rast(bio_file[1])
            extracted <- terra::extract(r, pts)
            bio_values[, i] <- extracted[, 2]  # Column 2 contains the values
          }
          
          period_label <- "1981-2024"
          scenario_label <- "historical"
          
        } else {
          # Future data: All future periods now use 5m resolution
          scenario <- input$scenario
          
          incProgress(0.2, detail = "Loading future climate data...")
          
          folder_path <- file.path("data", paste0("WorldClim_Data_", time_period))
          
          if(!dir.exists(folder_path)) {
            stop(paste("Folder not found:", folder_path))
          }
          
          # Convert time_period format: 2021_2040 -> 2021-2040
          period_with_hyphen <- gsub("_", "-", time_period)
          
          # All future periods now use 5m resolution
          resolution <- "5m"
          
          # File pattern: wc2.1_5m_bioc_EC-Earth3-Veg_{scenario}_{period}.tif
          file_pattern <- paste0("wc2.1_", resolution, "_bioc_", model, "_", scenario, "_", period_with_hyphen, "\\.tif$")
          
          raster_file <- list.files(
            folder_path,
            pattern = file_pattern,
            full.names = TRUE,
            ignore.case = FALSE
          )
          
          if(length(raster_file) == 0) {
            # List available files for debugging
            all_files <- list.files(folder_path, pattern = "\\.tif$", full.names = FALSE)
            error_msg <- paste0(
              "Raster file not found!\n",
              "Looking for pattern: ", file_pattern, "\n",
              "In folder: ", folder_path, "\n\n",
              "Available files:\n",
              paste(all_files, collapse = "\n")
            )
            stop(error_msg)
          }
          
          incProgress(0.2, detail = "Reading raster...")
          
          # Load raster (contains all 19 bio variables)
          r <- terra::rast(raster_file[1])
          
          # Check number of layers and assign names
          n_layers <- terra::nlyr(r)
          if(n_layers >= 19) {
            names(r) <- paste0("bio", 1:19)
          } else {
            warning(paste("Expected 19 layers but found", n_layers))
            names(r) <- paste0("bio", 1:n_layers)
          }
          
          incProgress(0.3, detail = "Extracting values...")
          
          # Extract values
          bio_values <- terra::extract(r, pts)[, -1]  # Remove ID column
          
          # Ensure we have 19 columns
          if(ncol(bio_values) < 19) {
            # Add missing columns with NA
            for(i in (ncol(bio_values) + 1):19) {
              bio_values[[paste0("bio", i)]] <- NA
            }
          }
          
          period_label <- gsub("_", "-", time_period)
          scenario_label <- toupper(scenario)
        }
        
        incProgress(0.1, detail = "Finalizing...")
        
        # Combine with coordinates
        result <- cbind(coords, bio_values)
        
        # Add row IDs
        result <- cbind(id = paste0("Site_", 1:nrow(result)), result)
        
        extracted_data(result)
        
        output$status_message <- renderUI({
          div(class = "alert alert-success",
              icon("check-circle"),
              strong(" Success! "),
              sprintf("Extracted bioclimatic variables for %d location%s using %s data (%s).",
                      nrow(result), 
                      ifelse(nrow(result) > 1, "s", ""), 
                      period_label,
                      scenario_label))
        })
        
        showNotification("Extraction completed successfully!", type = "message", duration = 5)
        
      }, error = function(e) {
        output$status_message <- renderUI({
          div(class = "alert alert-danger",
              icon("exclamation-triangle"),
              strong(" Error: "), e$message)
        })
        showNotification(paste("Extraction failed:", e$message), type = "error", duration = 10)
      })
    })
  })
  
  # Control results display
  output$show_results <- reactive({
    !is.null(extracted_data())
  })
  outputOptions(output, "show_results", suspendWhenHidden = FALSE)
  
  # Preview table
  output$preview_table <- renderDT({
    req(extracted_data())
    
    datatable(
      extracted_data(),
      options = list(
        pageLength = 10,
        scrollX = TRUE,
        dom = 'tip'
      ),
      rownames = FALSE
    ) %>%
      formatRound(columns = grep("^bio", names(extracted_data()), value = TRUE), digits = 2)
  })
  
  # Download handler
  output$download_data <- downloadHandler(
    filename = function() {
      time_period <- input$time_period
      if(time_period == "1981_2024") {
        paste0("climate_data_historical_", time_period, "_", Sys.Date(), ".csv")
      } else {
        paste0("climate_data_", input$scenario, "_", time_period, "_", Sys.Date(), ".csv")
      }
    },
    content = function(file) {
      write.csv(extracted_data(), file, row.names = FALSE)
    }
  )
}

# ============================================================
# RUN APP
# ============================================================
shinyApp(ui, server)