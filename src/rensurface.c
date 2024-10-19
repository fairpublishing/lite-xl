#include "rensurface.h"

void rensurf_init(RenSurface *rs, int x_origin, int y_origin) {
  rs->surface = NULL;
  rs->texture = NULL;
  rencache_init(&rs->rencache, x_origin, y_origin);
}

void rensurf_setup(RenSurface *rs, SDL_Renderer *renderer, int w, int h, int scale) {
  /* Note that w and h here should always be in pixels and obtained from
     a call to SDL_GL_GetDrawableSize(). */
  fprintf(stderr, "DEBUG: creating new surface (%4d, %4d)[%d]\n", w, h, scale);
  if (rs->surface) {
    SDL_FreeSurface(rs->surface);
  }
  rs->surface = SDL_CreateRGBSurfaceWithFormat(0, w, h, 32, SDL_PIXELFORMAT_BGRA32);
  if (!rs->surface) {
    fprintf(stderr, "Error creating surface: %s", SDL_GetError());
    exit(1);
  }
  if (rs->texture) {
    SDL_DestroyTexture(rs->texture);
  }
  rs->texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_BGRA32, SDL_TEXTUREACCESS_STREAMING, w, h);
  rs->scale = scale;
}


void rensurf_update_rects(RenSurface *rs, RenRect *rects, int count) {
  const int scale = rs->scale;
  for (int i = 0; i < count; i++) {
    const RenRect *r = &rects[i];
    const int x = scale * r->x, y = scale * r->y;
    const int w = scale * r->width, h = scale * r->height;
    const SDL_Rect sr = {.x = x, .y = y, .w = w, .h = h};
    int32_t *pixels = ((int32_t *) rs->surface->pixels) + x + rs->surface->w * y;
    SDL_UpdateTexture(rs->texture, &sr, pixels, rs->surface->w * 4);
  }
}

void rensurf_free(RenSurface *rs) {
  SDL_DestroyTexture(rs->texture);
  SDL_FreeSurface(rs->surface);
}

void rensurf_get_rect(RenSurface *rs, int *x, int *y, int *w, int *h) {
  *x = rs->rencache.x_origin;
  *y = rs->rencache.y_origin;
  *w = rs->surface->w;
  *h = rs->surface->h;
}
