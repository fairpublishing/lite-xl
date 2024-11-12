#include <SDL.h>
#include <stdbool.h>
#include <stdio.h>

#define WINDOW_WIDTH 800
#define WINDOW_HEIGHT 600
#define ATLAS_WIDTH 256
#define ATLAS_HEIGHT 256
#define GLYPH_SIZE 32  // Size of each glyph cell

typedef struct {
    SDL_Rect source;
    SDL_Rect destination;
} AtlasRegion;

// Function to draw a simple glyph representing letter 'A'
void draw_glyph_A(SDL_Surface* surface, int x, int y, Uint32 color) {
    SDL_Rect pixel;
    pixel.w = 1;
    pixel.h = 1;
    
    // Draw an 'A' shape (simplified 7x9 pixels)
    int A_pattern[] = {
        0,0,1,1,1,0,0,
        0,1,0,0,0,1,0,
        0,1,0,0,0,1,0,
        0,1,0,0,0,1,0,
        1,1,1,1,1,1,1,
        1,0,0,0,0,0,1,
        1,0,0,0,0,0,1,
        1,0,0,0,0,0,1,
        1,0,0,0,0,0,1
    };
    
    for (int py = 0; py < 9; py++) {
        for (int px = 0; px < 7; px++) {
            if (A_pattern[py * 7 + px]) {
                pixel.x = x + px + 4;  // Centered in glyph cell
                pixel.y = y + py + 4;
                SDL_FillRect(surface, &pixel, color);
            }
        }
    }
}

// Function to draw a simple glyph representing letter 'B'
void draw_glyph_B(SDL_Surface* surface, int x, int y, Uint32 color) {
    SDL_Rect pixel;
    pixel.w = 1;
    pixel.h = 1;
    
    // Draw a 'B' shape (simplified 7x9 pixels)
    int B_pattern[] = {
        1,1,1,1,1,0,0,
        1,0,0,0,0,1,0,
        1,0,0,0,0,1,0,
        1,1,1,1,1,0,0,
        1,0,0,0,0,1,0,
        1,0,0,0,0,1,0,
        1,0,0,0,0,1,0,
        1,0,0,0,0,1,0,
        1,1,1,1,1,0,0
    };
    
    for (int py = 0; py < 9; py++) {
        for (int px = 0; px < 7; px++) {
            if (B_pattern[py * 7 + px]) {
                pixel.x = x + px + 4;
                pixel.y = y + py + 4;
                SDL_FillRect(surface, &pixel, color);
            }
        }
    }
}

// Function to draw a simple glyph representing '+'
void draw_glyph_plus(SDL_Surface* surface, int x, int y, Uint32 color) {
    SDL_Rect pixel;
    pixel.w = 1;
    pixel.h = 1;
    
    // Draw a '+' shape (simplified 7x7 pixels)
    int plus_pattern[] = {
        0,0,0,1,0,0,0,
        0,0,0,1,0,0,0,
        0,0,0,1,0,0,0,
        1,1,1,1,1,1,1,
        0,0,0,1,0,0,0,
        0,0,0,1,0,0,0,
        0,0,0,1,0,0,0
    };
    
    for (int py = 0; py < 7; py++) {
        for (int px = 0; px < 7; px++) {
            if (plus_pattern[py * 7 + px]) {
                pixel.x = x + px + 4;
                pixel.y = y + py + 4;
                SDL_FillRect(surface, &pixel, color);
            }
        }
    }
}

SDL_Surface* create_atlas(void) {
    SDL_Surface* atlas = SDL_CreateRGBSurface(0, ATLAS_WIDTH, ATLAS_HEIGHT, 32,
                                             0xFF000000,
                                             0x00FF0000,
                                             0x0000FF00,
                                             0x000000FF);
    if (!atlas) {
        printf("Failed to create atlas surface: %s\n", SDL_GetError());
        return NULL;
    }

    // Fill atlas with black background
    SDL_FillRect(atlas, NULL, SDL_MapRGBA(atlas->format, 0, 0, 0, 255));

    // Colors for our glyphs
    Uint32 colors[] = {
        SDL_MapRGBA(atlas->format, 255, 255, 255, 255),  // White
        SDL_MapRGBA(atlas->format, 255, 255, 0, 255),    // Yellow
        SDL_MapRGBA(atlas->format, 0, 255, 0, 255)       // Green
    };

    // Draw glyphs in different colors and positions
    draw_glyph_A(atlas, 0, 0, colors[0]);          // White 'A' at (0,0)
    draw_glyph_B(atlas, GLYPH_SIZE, 0, colors[1]); // Yellow 'B' at (32,0)
    draw_glyph_plus(atlas, 0, GLYPH_SIZE, colors[2]); // Green '+' at (0,32)
    
    // Add more glyphs with different colors in a grid pattern
    draw_glyph_A(atlas, GLYPH_SIZE*2, 0, colors[2]);        // Green 'A'
    draw_glyph_B(atlas, GLYPH_SIZE*2, GLYPH_SIZE, colors[0]); // White 'B'
    draw_glyph_plus(atlas, GLYPH_SIZE, GLYPH_SIZE, colors[1]); // Yellow '+'

    return atlas;
}

int main(int argc, char* argv[]) {
    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        printf("SDL initialization failed: %s\n", SDL_GetError());
        return 1;
    }

    SDL_Window* window = SDL_CreateWindow("SDL Atlas Example with Glyphs",
                                        SDL_WINDOWPOS_UNDEFINED,
                                        SDL_WINDOWPOS_UNDEFINED,
                                        WINDOW_WIDTH, WINDOW_HEIGHT,
                                        SDL_WINDOW_SHOWN);
    if (!window) {
        printf("Window creation failed: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }

    SDL_Renderer* renderer = SDL_CreateRenderer(window, -1,
                                              SDL_RENDERER_ACCELERATED |
                                              SDL_RENDERER_PRESENTVSYNC);
    if (!renderer) {
        printf("Renderer creation failed: %s\n", SDL_GetError());
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }

    SDL_Surface* atlas = create_atlas();
    if (!atlas) {
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }

    // Create a surface to compose our final image
    SDL_Surface* compose_surface = SDL_CreateRGBSurface(0,
                                                       WINDOW_WIDTH,
                                                       WINDOW_HEIGHT,
                                                       32,
                                                       atlas->format->Rmask,
                                                       atlas->format->Gmask,
                                                       atlas->format->Bmask,
                                                       atlas->format->Amask);
    if (!compose_surface) {
        printf("Failed to create compose surface: %s\n", SDL_GetError());
        SDL_FreeSurface(atlas);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }

    // Fill background with dark gray
    SDL_FillRect(compose_surface, NULL,
                SDL_MapRGB(compose_surface->format, 32, 32, 32));

    // Define regions to copy from atlas (each glyph is 32x32)
    AtlasRegion regions[] = {
        // White 'A'
        {{0, 0, GLYPH_SIZE, GLYPH_SIZE}, {50, 50, GLYPH_SIZE*2, GLYPH_SIZE*2}},
        // Yellow 'B'
        {{GLYPH_SIZE, 0, GLYPH_SIZE, GLYPH_SIZE}, {150, 150, GLYPH_SIZE, GLYPH_SIZE}},
        // Green '+'
        {{0, GLYPH_SIZE, GLYPH_SIZE, GLYPH_SIZE}, {300, 100, GLYPH_SIZE*3, GLYPH_SIZE*3}},
        // Green 'A'
        {{GLYPH_SIZE*2, 0, GLYPH_SIZE, GLYPH_SIZE}, {400, 200, GLYPH_SIZE, GLYPH_SIZE}}
    };

    // Copy regions from atlas to compose surface
    for (size_t i = 0; i < sizeof(regions) / sizeof(regions[0]); i++) {
        SDL_BlitScaled(atlas, &regions[i].source,
                      compose_surface, &regions[i].destination);
    }

    // Create texture from compose surface
    SDL_Texture* texture = SDL_CreateTextureFromSurface(renderer, compose_surface);
    if (!texture) {
        printf("Failed to create texture: %s\n", SDL_GetError());
        SDL_FreeSurface(compose_surface);
        SDL_FreeSurface(atlas);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }

    // Main loop
    bool running = true;
    SDL_Event event;

    while (running) {
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT) {
                running = false;
            }
        }

        SDL_RenderClear(renderer);
        SDL_RenderCopy(renderer, texture, NULL, NULL);
        SDL_RenderPresent(renderer);
    }

    // Cleanup
    SDL_DestroyTexture(texture);
    SDL_FreeSurface(compose_surface);
    SDL_FreeSurface(atlas);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}
