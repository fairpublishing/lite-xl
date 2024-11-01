#ifndef DEBUG_RENDER_LOG_H
#define DEBUG_RENDER_LOG_H

#include <SDL.h>
#include "rensurface.h"

void debug_render_log_init(const char* log_dir);
void debug_render_log_surface(RenSurface *rs, int x, int y);
void debug_render_log_rect(SDL_Rect *r, SDL_Color color);
void debug_render_log_frame(void);

#endif
