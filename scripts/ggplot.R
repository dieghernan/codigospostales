library(ggplot2)
library(dplyr)
library(sf)
library(mapSpain)

# Une todos
files <- list.files("data/provs", pattern = ".gpkg$", full.names = TRUE)

all <- lapply(files, st_read, quiet = TRUE)

all <- bind_rows(all)

provs <- esp_get_prov_siane(moveCAN = FALSE) %>%
  st_transform(st_crs(all))

p <- ggplot(provs) +
  geom_sf(size=0.01) +
  geom_sf(data=all, fill="blue", size=0.01) +
  theme_void() +
  theme(plot.title = element_text(hjust = .5)) +
  labs(title = "Grado de avance")

ggsave("data/avance.png", p, dpi = 300)


# Dataset con municipios sin CP

all %>% st_drop_geometry() %>%
  filter(is.na(COD_POSTAL)) %>%
  readr::write_csv("data//full_analisis/missing.csv")
  
