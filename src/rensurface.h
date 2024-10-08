#ifndef RENSURFACE_H
#define RENSURFACE_H

#include "rencache.h"

#include <SDL.h>

struct RenSurface {
  SDL_Surface *surface;
  SDL_Texture *texture;
  RenCache rencache;
  int scale;
};

extern void rensurf_init(RenSurface *rs, int x_origin, int y_origin);
extern void rensurf_setup(RenSurface *rs, SDL_Renderer *renderer, int w, int h, int scale);
extern void rensurf_update_rects(RenSurface *rs, RenRect *rects, int count);
extern void rensurf_free(RenSurface *rs);
extern void rensurf_get_size(RenSurface *rs, int *w, int *h);

#endif

