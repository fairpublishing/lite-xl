#pragma once

#include <SDL.h>

extern int save_surface_to_png(SDL_Surface* surface, const char* filename);
extern void save_texture_to_png(SDL_Renderer *ren, SDL_Texture *tex, const char *filename);

