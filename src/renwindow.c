#include <assert.h>
#include <stdio.h>
#include "renwindow.h"

#include <SDL_image.h>

/* Query surface size and returns the scale factor. */
int renwin_get_size(RenWindow *ren, int *w_pixels, int *h_pixels) {
  int w_points, h_points;
  SDL_GL_GetDrawableSize(ren->window, w_pixels, h_pixels);
  SDL_GetWindowSize(ren->window, &w_points, &h_points);
  /* We consider that the ratio pixel/point will always be an integer and
     it is the same along the x and the y axis. */
  assert(*w_pixels % w_points == 0 && *h_pixels % h_points == 0 && *w_pixels / w_points == *h_pixels / h_points);
  return *w_pixels / w_points;
}


void renwin_init_renderer(RenWindow *ren) {
  /* We assume here "ren" is zero-initialized */
  ren->renderer = SDL_CreateRenderer(ren->window, -1, 0);
  ren->scale = renwin_get_size(ren, &ren->w_pixels, &ren->h_pixels);
}

void renwin_resize_window(RenWindow *ren) {
  ren->scale = renwin_get_size(ren, &ren->w_pixels, &ren->h_pixels);
}

#include "debug-image-save.c"

void renwin_render_surface(RenWindow *ren, RenSurface *rs, int x, int y) {
  /* Width and height of the surface, in pixels. */
  const int w = rs->surface->w, h = rs->surface->h;
  fprintf(stderr, "DEBUG: render surface (%4d, %4d) to position (%4d, %4d)\n", w, h, x, y);
  if (0 && w > 0 && h > 0) {
    char buf[1024];
    sprintf(buf, "surface-%d-%d-%d-%d.png", x, y, w, h);
    saveSurfaceToPNG(rs->surface, buf);
    sprintf(buf, "texture-%d-%d-%d-%d.png", x, y, w, h);
    save_texture(ren->renderer, rs->texture, buf);
  }
  const SDL_Rect dst = { x, y, w, h };
  SDL_RenderCopy(ren->renderer, rs->texture, NULL, &dst);
}

void renwin_present(RenWindow *ren) {
  static bool initial_frame = true;
  if (initial_frame) {
    SDL_ShowWindow(ren->window);
    initial_frame = false;
  }
  SDL_RenderPresent(ren->renderer);
}

void renwin_set_viewport(RenWindow *ren, const SDL_Rect *r) {
  SDL_RenderSetViewport(ren->renderer, r);
}

void renwin_free(RenWindow *ren) {
  SDL_DestroyWindow(ren->window);
  ren->window = NULL;
  SDL_DestroyRenderer(ren->renderer);
}

void renwin_render_fill_rect(RenWindow *ren, SDL_Rect *rect, SDL_Color color) {
  SDL_SetRenderDrawColor(ren->renderer, color.r, color.g, color.b, color.a);
  SDL_RenderFillRect(ren->renderer, rect);
}
