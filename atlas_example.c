#include <SDL.h>
#include <stdbool.h>
#include <stdio.h>
#include <ft2build.h>
#include FT_FREETYPE_H

#define WINDOW_WIDTH 800
#define WINDOW_HEIGHT 600
#define ATLAS_WIDTH 512
#define ATLAS_HEIGHT 512
#define FONT_SIZE 32

typedef struct {
    SDL_Rect source;
    SDL_Rect destination;
} AtlasRegion;

// Function to render a glyph to the atlas surface
SDL_bool render_glyph(FT_Face face, char c, SDL_Surface* atlas, int x, int y) {
    if (FT_Load_Char(face, c, FT_LOAD_RENDER)) {
        printf("Failed to load glyph '%c'\n", c);
        return SDL_FALSE;
    }

    FT_GlyphSlot slot = face->glyph;
    FT_Bitmap* bitmap = &slot->bitmap;

    // For each pixel in the glyph bitmap
    for (unsigned int row = 0; row < bitmap->rows; row++) {
        for (unsigned int col = 0; col < bitmap->width; col++) {
            unsigned char pixel = bitmap->buffer[row * bitmap->pitch + col];
            
            // Convert grayscale value to SDL color
            Uint32 color = SDL_MapRGBA(atlas->format, pixel, pixel, pixel, pixel);
            
            SDL_Rect pixel_rect = {
                x + col,
                y + row,
                1,
                1
            };
            
            SDL_FillRect(atlas, &pixel_rect, color);
        }
    }
    
    return SDL_TRUE;
}

SDL_Surface* create_atlas(FT_Face face) {
    SDL_Surface* atlas = SDL_CreateRGBSurface(0, ATLAS_WIDTH, ATLAS_HEIGHT, 32,
                                             0xFF000000,
                                             0x00FF0000,
                                             0x0000FF00,
                                             0x000000FF);
    if (!atlas) {
        printf("Failed to create atlas surface: %s\n", SDL_GetError());
        return NULL;
    }

    // Fill atlas with transparent black
    SDL_FillRect(atlas, NULL, SDL_MapRGBA(atlas->format, 0, 0, 0, 0));

    // Set the font size
    FT_Set_Pixel_Sizes(face, 0, FONT_SIZE);

    // Render some sample characters
    const char* chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
    int x = 0, y = 0;
    int max_height = FONT_SIZE;

    for (const char* p = chars; *p; p++) {
        if (x + FONT_SIZE >= ATLAS_WIDTH) {
            x = 0;
            y += max_height;
            if (y + max_height >= ATLAS_HEIGHT) break;
        }

        if (render_glyph(face, *p, atlas, x, y)) {
            x += FONT_SIZE;
        }
    }

    return atlas;
}

int main(int argc, char* argv[]) {
    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        printf("SDL initialization failed: %s\n", SDL_GetError());
        return 1;
    }

    // Initialize FreeType
    FT_Library ft_library;
    if (FT_Init_FreeType(&ft_library)) {
        printf("Could not initialize FreeType\n");
        SDL_Quit();
        return 1;
    }

    // Load the font
    FT_Face face;
    if (FT_New_Face(ft_library, "data/fonts/FiraSans-Regular.ttf", 0, &face)) {
        printf("Could not load font\n");
        FT_Done_FreeType(ft_library);
        SDL_Quit();
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

    SDL_Surface* atlas = create_atlas(face);
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
        {{0, 0, FONT_SIZE, FONT_SIZE}, {50, 50, FONT_SIZE*2, FONT_SIZE*2}},
        // Yellow 'B'
        {{FONT_SIZE, 0, FONT_SIZE, FONT_SIZE}, {150, 150, FONT_SIZE, FONT_SIZE}},
        // Green '+'
        {{0, FONT_SIZE, FONT_SIZE, FONT_SIZE}, {300, 100, FONT_SIZE*3, FONT_SIZE*3}},
        // Green 'A'
        {{FONT_SIZE*2, 0, FONT_SIZE, FONT_SIZE}, {400, 200, FONT_SIZE, FONT_SIZE}}
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
    // Cleanup FreeType
    FT_Done_Face(face);
    FT_Done_FreeType(ft_library);
    
    SDL_Quit();
    return 0;
}
