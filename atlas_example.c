#include <SDL.h>
#include <stdbool.h>
#include <stdio.h>

#define WINDOW_WIDTH 800
#define WINDOW_HEIGHT 600
#define ATLAS_WIDTH 256
#define ATLAS_HEIGHT 256

// Structure to store atlas region coordinates
typedef struct {
    SDL_Rect source;      // Region in the atlas
    SDL_Rect destination; // Where to render on screen
} AtlasRegion;

// Function to create a simple pixel atlas
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

    // Fill atlas with some example patterns
    SDL_Rect regions[] = {
        {0, 0, 64, 64},     // Red square
        {64, 0, 64, 64},    // Green square
        {128, 0, 64, 64},   // Blue square
        {0, 64, 128, 128}   // Checkered pattern
    };

    Uint32 colors[] = {
        SDL_MapRGBA(atlas->format, 255, 0, 0, 255),    // Red
        SDL_MapRGBA(atlas->format, 0, 255, 0, 255),    // Green
        SDL_MapRGBA(atlas->format, 0, 0, 255, 255),    // Blue
        SDL_MapRGBA(atlas->format, 255, 255, 255, 255) // White
    };

    // Fill the solid color regions
    for (int i = 0; i < 3; i++) {
        SDL_FillRect(atlas, &regions[i], colors[i]);
    }

    // Create checkered pattern
    int checker_size = 16;
    for (int y = 0; y < regions[3].h; y += checker_size) {
        for (int x = 0; x < regions[3].w; x += checker_size) {
            SDL_Rect checker = {
                regions[3].x + x,
                regions[3].y + y,
                checker_size,
                checker_size
            };
            Uint32 color = ((x / checker_size + y / checker_size) % 2) ? colors[3] : colors[0];
            SDL_FillRect(atlas, &checker, color);
        }
    }

    return atlas;
}

int main(int argc, char* argv[]) {
    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        printf("SDL initialization failed: %s\n", SDL_GetError());
        return 1;
    }

    SDL_Window* window = SDL_CreateWindow("SDL Atlas Example",
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

    // Create our atlas
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

    // Define regions to copy from atlas
    AtlasRegion regions[] = {
        // Red square
        {{0, 0, 64, 64}, {50, 50, 64, 64}},
        // Green square
        {{64, 0, 64, 64}, {150, 150, 128, 128}},  // Note: scaled up
        // Blue square
        {{128, 0, 64, 64}, {300, 100, 64, 64}},
        // Checkered pattern
        {{0, 64, 128, 128}, {400, 200, 256, 256}} // Note: scaled up
    };

    // Fill background with dark gray
    SDL_FillRect(compose_surface, NULL,
                SDL_MapRGB(compose_surface->format, 64, 64, 64));

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
