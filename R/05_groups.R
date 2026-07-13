# ------------------------------------------------------------------
# 05_groups.R  -- related-party groups (ADR-002, ADR-007)
# founder_id is the group key; shared address_hash upgrades a link to "strong".
# Group typology: profit-shifting -- entities in the same group with a wide
# spread of effective tax rates / margins (profit parked in low-tax members).
# ------------------------------------------------------------------

suppressPackageStartupMessages({
  library(dplyr)
  library(igraph)
})

build_groups <- function(cy, comp, config = CONFIG) {
  # collapse to company level: founder, address(es), mean ETR / margin, size
  by_company <- cy %>%
    group_by(company_id, founder_id) %>%
    summarise(
      address_hashes  = paste(sort(unique(address_hash)), collapse = "|"),
      mean_etr        = mean(etr, na.rm = TRUE),
      mean_op_margin  = mean(operating_margin, na.rm = TRUE),
      revenue_max     = max(revenue, na.rm = TRUE),
      taxes_total     = sum(taxes_paid, na.rm = TRUE),
      .groups = "drop"
    )

  groups <- by_company %>%
    group_by(founder_id) %>%
    summarise(
      n_companies   = dplyr::n_distinct(company_id),
      companies     = paste(sort(unique(company_id)), collapse = ", "),
      shares_address = any(duplicated(unlist(strsplit(address_hashes, "\\|")))),
      etr_spread    = suppressWarnings(diff(range(mean_etr, na.rm = TRUE))),
      margin_spread = suppressWarnings(diff(range(mean_op_margin, na.rm = TRUE))),
      group_revenue = sum(revenue_max, na.rm = TRUE),
      group_taxes   = sum(taxes_total, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    filter(n_companies >= 2) %>%
    mutate(
      link_strength = ifelse(shares_address, "strong", "founder_only"),
      etr_spread    = ifelse(is.finite(etr_spread), etr_spread, NA_real_),
      margin_spread = ifelse(is.finite(margin_spread), margin_spread, NA_real_)
    ) %>%
    arrange(desc(etr_spread), desc(group_revenue))

  attr(groups, "n_multi_company_founders") <- nrow(groups)
  groups
}

# Двудольный граф аффилированности: учредители (круги) — компании (квадраты).
build_affiliation_graph <- function(cy, groups, comp = NULL) {
  if (nrow(groups) == 0) return(NULL)

  edges <- cy %>%
    distinct(company_id, founder_id) %>%
    filter(founder_id %in% groups$founder_id) %>%
    transmute(from = founder_id, to = company_id)

  if (nrow(edges) == 0) return(NULL)

  founders  <- sort(unique(edges$from))
  companies <- sort(unique(edges$to))
  verts <- rbind(
    data.frame(name = founders,  type = TRUE,  stringsAsFactors = FALSE),
    data.frame(name = companies, type = FALSE, stringsAsFactors = FALSE)
  )

  g <- graph_from_data_frame(edges, directed = FALSE, vertices = verts)

  ls_map <- setNames(groups$link_strength, groups$founder_id)
  V(g)$node_kind <- ifelse(V(g)$type, "founder", "company")
  V(g)$link_strength <- ifelse(V(g)$type, ls_map[V(g)$name], NA_character_)

  if (!is.null(comp)) {
    bucket_map <- setNames(as.character(comp$bucket), comp$company_id)
    V(g)$bucket <- ifelse(V(g)$type, NA_character_, bucket_map[V(g)$name])
  }

  g
}

open_graph_device <- function(file = NULL, width = 10, height = 7) {
  if (!is.null(file)) {
    if (requireNamespace("ragg", quietly = TRUE)) {
      ragg::agg_png(file, width = width, height = height, units = "in", res = 120)
    } else if (grDevices::capabilities("cairo")) {
      grDevices::cairo_png(file, width = width, height = height, units = "in", res = 120)
    } else {
      png(file, width = width, height = height, units = "in", res = 120)
    }
  }
  par(family = if (.Platform$OS.type == "windows") "Arial" else "sans")
}

plot_affiliation_graph <- function(g, file = NULL, title = "Группы аффилированности") {
  if (is.null(g) || gorder(g) == 0) return(invisible(NULL))

  bucket_colors <- c(
    urgent           = "#D55E00",
    background       = "#0072B2",
    economic_signal  = "#E69F00",
    not_flagged      = "#999999"
  )

  cols <- ifelse(
    V(g)$type,
    "#56B4E9",
    bucket_colors[V(g)$bucket]
  )
  cols[is.na(cols)] <- "#CCCCCC"

  shapes <- ifelse(V(g)$type, "circle", "square")
  sizes  <- ifelse(V(g)$type, 14, 8)

  # подписи: все учредители; компании — только с флагами риска
  labels <- ifelse(
    V(g)$type,
    V(g)$name,
    ifelse(V(g)$bucket %in% c("urgent", "background", "economic_signal"), V(g)$name, NA_character_)
  )

  # толщина/цвет рёбер: «strong» = общий адрес (ADR-007)
  # ends() по умолчанию возвращает имена, а не индексы — нужен names = FALSE
  el <- ends(g, E(g), names = FALSE)
  founder_ls <- ifelse(
    V(g)$type[el[, 1]],
    V(g)$link_strength[el[, 1]],
    V(g)$link_strength[el[, 2]]
  )
  edge_cols  <- ifelse(founder_ls == "strong", "#222222", "#666666")
  edge_width <- ifelse(founder_ls == "strong", 5.0, 3.0)

  open_graph_device(file)
  if (!is.null(file)) on.exit(dev.off(), add = TRUE)

  plot(
    g,
    layout = layout_with_graphopt(g, niter = 1000),
    vertex.shape = shapes,
    vertex.color = cols,
    vertex.size = sizes,
    vertex.label = labels,
    vertex.label.cex = ifelse(V(g)$type, 0.8, 0.55),
    vertex.label.color = "#222222",
    vertex.label.dist = ifelse(V(g)$type, 0.5, 0),
    vertex.frame.color = NA,
    edge.color = edge_cols,
    edge.width = edge_width,
    main = title
  )

  legend(
    "bottomleft",
    legend = c(
      "Учредитель", "Компания (urgent)", "Компания (background)",
      "Компания (economic signal)", "Компания (без флагов)", "Связь: общий адрес"
    ),
    pch = c(21, 22, 22, 22, 22, NA),
    lty = c(NA, NA, NA, NA, NA, 1),
    lwd = c(NA, NA, NA, NA, NA, 4),
    col = c(NA, NA, NA, NA, NA, "#444444"),
    pt.bg = c("#56B4E9", bucket_colors["urgent"], bucket_colors["background"],
              bucket_colors["economic_signal"], bucket_colors["not_flagged"], NA),
    pt.cex = 1.2,
    bty = "n",
    cex = 0.75
  )

  invisible(g)
}
