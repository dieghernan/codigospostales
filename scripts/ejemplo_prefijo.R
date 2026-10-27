library(sf)
library(ggplot2)

cp <- st_read(
  "data/codigos_postales_simplificado.gpkg",
  query = "SELECT * FROM codigos_postales WHERE COD_POSTAL LIKE '28%'",
  quiet = TRUE
)

mapa <- ggplot(cp) +
  geom_sf(fill = "#dbe8ef", color = "#34495e", linewidth = 0.15) +
  theme_void() +
  labs(
    title = "C\u00f3digos postales con prefijo 28",
    subtitle = "Delimitaciones estimadas \u00b7 versi\u00f3n simplificada",
    caption = paste(
      "Fuentes: CartoCiudad (IGN/CNIG)",
      "L\u00edmites administrativos: Goerlich y P\u00e9rez V\u00e1zquez (2025)",
      "Elaboraci\u00f3n: dieghernan (dieghernan.github.io)",
      sep = "\n"
    )
  ) +
  theme(
    plot.background = element_rect(fill = "white", color = NA),
    plot.title = element_text(face = "bold"),
    plot.caption = element_text(hjust = 0, size = 9),
    plot.margin = margin(15, 15, 15, 15)
  )

dir.create("docs/assets/img", recursive = TRUE, showWarnings = FALSE)
ggsave(
  "docs/assets/img/codigos-postales-28.png",
  mapa,
  width = 7,
  height = 7,
  dpi = 160
)
