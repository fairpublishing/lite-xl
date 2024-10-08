#include <assert.h>
#include <stdio.h>
#include "renwindow.h"

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


void renwin_init_surface(RenWindow *ren) {
  int w_pixels, h_pixels;
  /* We assume here "ren" is zero-initialized */
  ren->renderer = SDL_CreateRenderer(ren->window, -1, 0);
  ren->scale = renwin_get_size(ren, &w_pixels, &h_pixels);
  rensurf_init(&ren->rensurface, 0, 0);
  rensurf_setup(&ren->rensurface, ren->renderer, w_pixels, h_pixels, ren->scale);
}


void renwin_clip_to_surface(RenWindow *ren) {
  SDL_SetClipRect(renwin_get_surface(ren)->surface, NULL);
}


RenSurface *renwin_get_surface(RenWindow *ren) {
  return &ren->rensurface;
}

void renwin_resize_surface(UNUSED RenWindow *ren) {
  int new_w, new_h;
  int scale = renwin_get_size(ren, &new_w, &new_h);
  /* Note that (w, h) may differ from (new_w, new_h) on retina displays. */
  if (scale != ren->scale || new_w != ren->rensurface.surface->w || new_h != ren->rensurface.surface->h) {
    ren->scale = scale;
    rensurf_setup(&ren->rensurface, ren->renderer, new_w, new_h, ren->scale);
    renwin_clip_to_surface(ren);
  }
}

void renwin_show_window(RenWindow *ren) {
  SDL_ShowWindow(ren->window);
}

void renwin_render_surface(RenWindow *ren, RenSurface *rs, int x, int y) {
  /* Width and height of the surface, in pixels. */
  const int w = rs->surface->w, h = rs->surface->h;
  const int dx = (x < 0 ? -x : 0);
  const int dy = (y < 0 ? -y : 0);
  const SDL_Rect src = { dx    , dy    , w - dx, h - dy };
  const SDL_Rect dst = { x - dx, y - dy, w - dx, h - dy };
  SDL_RenderCopy(ren->renderer, ren->rensurface.texture, &src, &dst);
  SDL_RenderPresent(ren->renderer);
}

void renwin_free(RenWindow *ren) {
  SDL_DestroyWindow(ren->window);
  ren->window = NULL;
  SDL_DestroyRenderer(ren->renderer);
  rensurf_free(&ren->rensurface);
}
