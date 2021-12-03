#include <stdio.h>
#include <stdlib.h>
#include <err.h>

extern void start (int szer, int wys, float *M, float C, float waga);
extern void place (int ile, int x[], int y[], float temp[]);
extern void step();

struct Matrix {
    int width;
    int height;
    float *M;
};

void destroy_matrix(struct Matrix *m) {
    free(m->M);
}

struct Heaters {
    int n;
    int *x;
    int *y;
    float *temp;
};

void destroy_heaters(struct Heaters *h) {
    free(h->x);
    free(h->y);
    free(h->temp);
}

void read_file(struct Matrix *M, struct Heaters *H, float *cooler_temp, char *filename) {
    FILE *fptr;

    fptr = fopen(filename, "r");
    fscanf(fptr, "%d %d %f", &M->width, &M->height, cooler_temp);

    // Reserve memory for matrix, including the cooler's border, and double it to make an auxiliary one.
    M->M = malloc(2 * (M->width + 2) * (M->height + 2) * sizeof(float));

    if (!M->M)
        err(1, "An error occurred during matrix initialization.");

    for (int x = 1; x <= M->height; x++) {
        for (int y = 1; y <= M->width; y++) {
            fscanf(fptr, "%f", M->M + (x * (M->width + 2) + y));
        }
    }

    for (int i = 0; i < M->width + 2; i++) {
        M->M[i] = *cooler_temp;
        M->M[(M->height + 1) * (M->width + 2) + i] = *cooler_temp;
    }

    for (int i = 0; i < M->height + 2; i++) {
        M->M[i * (M->width + 2)] = *cooler_temp;
        M->M[i * (M->width + 2) + (M->width + 1)] = *cooler_temp;
    }

    fscanf(fptr, "%d", &H->n);

    H->x = malloc(H->n * sizeof (int));
    if (!H->x)
        err(1, "An error occurred during temp x_coords initialization.");

    H->y = malloc(H->n * sizeof (int));
    if (!H->y)
        err(1, "An error occurred during temp y_coords initialization.");

    H->temp = malloc(H->n * sizeof (float));
    if (!H->temp)
        err(1, "An error occurred during temp initialization.");

    for (int i = 0; i < H->n; i++) {
        fscanf(fptr, "%d %d %f", H->x + i, H->y + i, H->temp + i);
        M->M[(H->x[i] + 1) * (M->width + 2) + H->y[i] + 1] = H->temp[i];
    }

    fclose(fptr);
}

void print_matrix(struct Matrix M) {
    for (int x = 0; x < M.height + 2; x++) {
        for (int y = 0; y < M.width + 2; y++) {
            if (x == 0 || x == M.height + 1 || y == 0 || y == M.width + 1) {
                printf("\033[22;36m%0.3f\033[0m ", M.M[x * (M.width + 2) + y]);
            }
            else {
                printf("%0.3f ", M.M[x * (M.width + 2) + y]);
            }
        }

        printf("\n");
    }
}

void run_simulation(char *file_name, float m, int steps) {
    struct Matrix matrix;
    struct Heaters heaters;
    float cooler_temp;

    read_file(&matrix, &heaters, &cooler_temp, file_name);

    printf("Initial matrix:\n");
    print_matrix(matrix);

    start(matrix.width, matrix.height, matrix.M, cooler_temp, m);
    place(heaters.n, heaters.x, heaters.y, heaters.temp);

    for (int i = 0; i < steps; i++) {
        step();
        printf("After step %d...\n", i + 1);
        print_matrix(matrix);
        getc(stdin);
    }

    destroy_matrix(&matrix);
    destroy_heaters(&heaters);
}

int main(int argc, char *argv[]) {
    if (argc < 3) {
        printf("Usage: %s <file_name> <wage> <steps>\n", argv[0]);
        exit(1);
    }

    char *file_name = argv[1];
    float m = atof(argv[2]);
    int steps = atoi(argv[3]);

    run_simulation(file_name, m, steps);

    return 0;
}
