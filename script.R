   setwd("/Users/thaylaeduardamacieldesousa/Documents/Codex/project_eco_analysis")
   
   library(tidyverse)
   library(readxl)
   library(lubridate)
   library(slider)
   library(ggplot2)
   library(hrbrthemes)
   library(tidymodels)
   library(ranger)
   library(vip)
   library(leaflet)
   library(htmltools)
   
   # 1. Data Import & Cleaning
   raw_data <- read_excel("cote_dazur_wildfire_dataset_2023.xlsx", sheet = "Dados_Historicos_Met_Incendies")
   
   clean_data <- raw_data %>%
     mutate(
       Date = as.Date(Date),
       Code_INSEE = as.character(Code_INSEE),
       Commune = as.factor(Commune),
       Vegetation_Type = as.factor(Vegetation_Type),
       Incendie_Bnf = as.factor(Incendie_Bnf)
     ) %>%
     filter(!is.na(Temp_Max_C), !is.na(Humidite_Min_Pct))
   
   featured_data <- clean_data %>%
     arrange(Commune, Date) %>%
     group_by(Commune) %>%
     mutate(
       Temp_Humidity_Ratio = Temp_Max_C / (Humidite_Min_Pct + 1),
       Precip_7d_Sum = slide_dbl(Precip_Mm, sum, .before = 6, .complete = TRUE),
       Critical_Wind = if_else(Vent_Max_KmH > 30, 1, 0)
     ) %>%
     ungroup() %>%
     drop_na()
   
   glimpse(featured_data)
   
   # 2. Exploratory Visualization: Boxplot FWI
   p1 <- ggplot(featured_data, aes(x = Incendie_Bnf, y = FWI_Index, fill = Incendie_Bnf)) +
     geom_boxplot(
       width = 0.45,
       alpha = 0.85,
       color = "#1F2937",
       outlier.color = "#DC2626",
       outlier.alpha = 0.6,
       outlier.size = 1.8
     ) +
     scale_fill_manual(values = c("#64748B", "#EF4444")) +
     scale_x_discrete(labels = c("0" = "No Fire", "1" = "Fire Event")) +
     labs(
       title = "Fire Weather Index (FWI) vs. Wildfire Occurrence",
       subtitle = "Analysis of Meteorological Hazards in Alpes-Maritimes (Côte d'Azur, Summer 2023)",
       x = "Observed Fire Status",
       y = "FWI (Fire Weather Index)",
       caption = "Data Sources: Prométhée & Météo-France (SAFRAN)"
     ) +
     theme_ipsum(grid = "Y", base_size = 11) +
     theme(
       plot.title = element_text(hjust = 0.5, face = "bold", size = 13, color = "#0F172A"),
       plot.subtitle = element_text(hjust = 0.5, size = 9.5, color = "#475569", margin = margin(b = 12)),
       plot.caption = element_text(hjust = 0.5, size = 8, color = "#94A3B8", margin = margin(t = 10)),
       axis.title.x = element_text(hjust = 0.5, size = 10, face = "bold", color = "#334155", margin = margin(t = 8)),
       axis.title.y = element_text(hjust = 0.5, size = 10, face = "bold", color = "#334155", margin = margin(r = 8)),
       axis.text.x = element_text(size = 9.5, color = "#1E293B", face = "bold"),
       axis.text.y = element_text(size = 9, color = "#64748B"),
       legend.position = "none",
       plot.margin = margin(20, 20, 15, 20)
     )
   
   print(p1)
   ggsave("fwi_wildfire_distribution.png", plot = p1, width = 8, height = 6, dpi = 300)
   
   # 3. Exploratory Visualization: Temperature Timeline
   sober_palette <- c(
     "Antibes"                     = "#475569",
     "Cannes"                      = "#0F766E",
     "Grasse"                      = "#334155",
     "Menton"                      = "#1E3A8A",
     "Nice"                        = "#3F6212",
     "Tende"                       = "#78350F",
     "Valbonne (Sophia Antipolis)" = "#581C87",
     "Vence"                       = "#52525B"
   )
   
   p2 <- ggplot(featured_data, aes(x = Date, y = Temp_Max_C)) +
     geom_line(aes(color = Commune), linewidth = 0.4, alpha = 0.8) +
     geom_point(
       data = filter(featured_data, Incendie_Bnf == 1),
       aes(y = Temp_Max_C),
       color = "#DC2626",
       size = 0.85,
       alpha = 0.9
     ) +
     facet_wrap(~ Commune, ncol = 4, scales = "free_x") +
     scale_color_manual(values = sober_palette) +
     scale_x_date(date_labels = "%b", date_breaks = "1 month") +
     labs(
       title = "Daily Maximum Temperature & Wildfire Timeline",
       subtitle = "Temperature Trends across Alpes-Maritimes Communes (Red dots indicate confirmed fires)",
       x = "Observation Period (2023)",
       y = "Max Temperature (°C)",
       caption = "Data Sources: Prométhée & Météo-France (SAFRAN)"
     ) +
     theme_ipsum(grid = "Y", base_size = 10) +
     theme(
       plot.title = element_text(hjust = 0.5, face = "bold", size = 13, color = "#0F172A"),
       plot.subtitle = element_text(hjust = 0.5, size = 9.5, color = "#475569", margin = margin(b = 12)),
       plot.caption = element_text(hjust = 0.5, size = 8, color = "#94A3B8", margin = margin(t = 10)),
       strip.text = element_text(hjust = 0.5, size = 9, face = "bold", color = "#1E293B"),
       strip.background = element_rect(fill = "#F1F5F9", color = NA),
       axis.text.x = element_text(size = 7.5, color = "#64748B"),
       axis.text.y = element_text(size = 8, color = "#64748B"),
       axis.title.x = element_text(hjust = 0.5, size = 9.5, face = "bold", color = "#334155", margin = margin(t = 10)),
       axis.title.y = element_text(hjust = 0.5, size = 9.5, face = "bold", color = "#334155", margin = margin(r = 8)),
       legend.position = "none",
       plot.margin = margin(15, 15, 15, 15)
     )
   
   print(p2)
   ggsave("temperature_fire_timeline_faceted.png", plot = p2, width = 11, height = 6, dpi = 300)
   
   # 4. Machine Learning: Random Forest Classification
   set.seed(123)
   data_split <- initial_split(featured_data, prop = 0.80, strata = Incendie_Bnf)
   train_data <- training(data_split)
   test_data  <- testing(data_split)
   
   rf_recipe <- recipe(
     Incendie_Bnf ~ Temp_Max_C + Humidite_Min_Pct + Vent_Max_KmH + 
       Precip_7d_Sum + FWI_Index + Altitude_m + Temp_Humidity_Ratio + 
       Vegetation_Type, 
     data = train_data
   ) %>%
     step_dummy(all_nominal_predictors()) %>%
     step_normalize(all_numeric_predictors())
   
   rf_spec <- rand_forest(trees = 500, mtry = 3, min_n = 5) %>%
     set_engine("ranger", importance = "permutation") %>%
     set_mode("classification")
   
   rf_workflow <- workflow() %>%
     add_recipe(rf_recipe) %>%
     add_model(rf_spec)
   
   rf_fit <- fit(rf_workflow, data = train_data)
   
   results <- test_data %>%
     bind_cols(predict(rf_fit, test_data)) %>%
     bind_cols(predict(rf_fit, test_data, type = "prob"))
   
   conf_mat(results, truth = Incendie_Bnf, estimate = .pred_class)
   metrics(results, truth = Incendie_Bnf, estimate = .pred_class)
   
   rf_fit %>%
     extract_fit_parsnip() %>%
     vip(geom = "point", num_features = 8) +
     labs(title = "Feature Importance - Wildfire Risk Model") +
     theme_minimal()
   
   # 5. Spatial Risk Visualization: Interactive Map
   commune_coords <- tibble(
     Commune = c("Nice", "Grasse", "Valbonne (Sophia Antipolis)", "Cannes", "Menton", "Antibes", "Vence", "Tende"),
     lat = c(43.7102, 43.6602, 43.6413, 43.5528, 43.7745, 43.5804, 43.7223, 44.0875),
     lng = c(7.2620, 6.9238, 7.0084, 7.0174, 7.4976, 7.1251, 7.1127, 7.5938)
   )
   
   latest_risk_map <- featured_data %>%
     filter(Date == max(Date)) %>%
     inner_join(commune_coords, by = "Commune")
   
   map <- leaflet(latest_risk_map) %>%
     addProviderTiles(providers$Esri.WorldTopoMap) %>%
     setView(lng = 7.25, lat = 43.75, zoom = 9) %>%
     addCircleMarkers(
       lng = ~lng,
       lat = ~lat,
       radius = ~pmax(FWI_Index / 2.5, 6),
       color = "#1E293B",
       weight = 1.2,
       fillColor = ~if_else(FWI_Index >= 30, "#DC2626", "#059669"),
       fillOpacity = 0.8,
       label = ~Commune,
       labelOptions = labelOptions(
         noHide = TRUE,
         direction = "top",
         textOnly = FALSE,
         style = list(
           "font-weight" = "bold",
           "font-size" = "11px",
           "color" = "#0F172A",
           "background-color" = "rgba(255, 255, 255, 0.85)",
           "border-color" = "#CBD5E1",
           "padding" = "2px 6px",
           "border-radius" = "4px"
         )
       ),
       popup = ~paste0(
         "<div style='font-family: sans-serif; font-size: 12px; min-width: 150px;'>",
         "<h4 style='margin: 0 0 6px 0; color: #0F172A; border-bottom: 1px solid #E2E8F0; padding-bottom: 4px;'>", Commune, "</h4>",
         "<b>FWI Risk Index: </b> <span style='color:", if_else(FWI_Index >= 30, "#DC2626", "#059669"), "; font-weight: bold;'>", round(FWI_Index, 1), "</span><br>",
         "<b>Max Temp: </b>", round(Temp_Max_C, 1), " °C<br>",
         "<b>Max Wind: </b>", round(Vent_Max_KmH, 1), " km/h<br>",
         "<b>Date: </b>", Date,
         "</div>"
       )
     ) %>%
     addLegend(
       position = "bottomright",
       colors = c("#DC2626", "#059669"),
       labels = c("Critical Risk (FWI ≥ 30)", "Moderate / Low Risk (FWI < 30)"),
       title = "Wildfire Hazard Status",
       opacity = 0.9
     )
   
   print(map)
   
  