// Keep Rust FFI symbols from being stripped in iOS static linking.
// We only take addresses; no calls are made.

#ifdef __cplusplus
extern "C" {
#endif

// Core engine entry points.
extern void engine_push_points(void);
extern void engine_get_input_queue_len(void);
extern void engine_is_valid(void);
extern void engine_set_log_level(void);
extern void engine_set_active_layer(void);
extern void engine_set_layer_opacity(void);
extern void engine_set_layer_visible(void);
extern void engine_set_layer_clipping_mask(void);
extern void engine_set_layer_blend_mode(void);
extern void engine_reorder_layer(void);
extern void engine_set_view_flags(void);
extern void engine_clear_layer(void);
extern void engine_fill_layer(void);
extern void engine_bucket_fill(void);
extern void engine_magic_wand_mask(void);
extern void engine_read_layer(void);
extern void engine_read_layer_preview(void);
extern void engine_write_layer(void);
extern void engine_translate_layer(void);
extern void engine_set_layer_transform_preview(void);
extern void engine_apply_layer_transform(void);
extern void engine_get_layer_bounds(void);
extern void engine_set_selection_mask(void);
extern void engine_reset_canvas(void);
extern void engine_reset_canvas_with_layers(void);
extern void engine_resize_canvas(void);
extern void engine_undo(void);
extern void engine_redo(void);
extern void engine_set_brush(void);
extern void engine_spray_begin(void);
extern void engine_spray_draw(void);
extern void engine_spray_end(void);
extern void engine_apply_filter(void);
extern void engine_apply_antialias(void);

// Exported keepalive function called from Swift.
void rust_engine_keepalive(void) {
  static void *const symbols[] = {
    (void *)&engine_push_points,
    (void *)&engine_get_input_queue_len,
    (void *)&engine_set_log_level,
    (void *)&engine_is_valid,
    (void *)&engine_set_active_layer,
    (void *)&engine_set_layer_opacity,
    (void *)&engine_set_layer_visible,
    (void *)&engine_set_layer_clipping_mask,
    (void *)&engine_set_layer_blend_mode,
    (void *)&engine_reorder_layer,
    (void *)&engine_set_view_flags,
    (void *)&engine_clear_layer,
    (void *)&engine_fill_layer,
    (void *)&engine_bucket_fill,
    (void *)&engine_magic_wand_mask,
    (void *)&engine_read_layer,
    (void *)&engine_read_layer_preview,
    (void *)&engine_write_layer,
    (void *)&engine_translate_layer,
    (void *)&engine_set_layer_transform_preview,
    (void *)&engine_apply_layer_transform,
    (void *)&engine_get_layer_bounds,
    (void *)&engine_set_selection_mask,
    (void *)&engine_reset_canvas,
    (void *)&engine_reset_canvas_with_layers,
    (void *)&engine_resize_canvas,
    (void *)&engine_undo,
    (void *)&engine_redo,
    (void *)&engine_set_brush,
    (void *)&engine_spray_begin,
    (void *)&engine_spray_draw,
    (void *)&engine_spray_end,
    (void *)&engine_apply_filter,
    (void *)&engine_apply_antialias,
  };
  (void)symbols;
}

#ifdef __cplusplus
}
#endif
