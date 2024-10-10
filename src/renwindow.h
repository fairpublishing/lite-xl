#include <SDL.h>
#include "renderer.h"
#include "rensurface.h"

struct RenWindow {
  SDL_Window *window;
  SDL_Renderer *renderer;
  int w_pixels, h_pixels;
  int scale;
};
typedef struct RenWindow RenWindow;

int renwin_get_size(RenWindow *ren, int *w_pixels, int *h_pixels);
void renwin_init_renderer(RenWindow *ren);
// void renwin_clip_to_surface(RenWindow *ren);
void renwin_resize_window(RenWindow *ren);
void renwin_present(RenWindow *ren);
void renwin_render_surface(RenWindow *ren, RenSurface *rs, int x, int y);
void renwin_free(RenWindow *ren);
// RenSurface *renwin_get_surface(RenWindow *ren);

