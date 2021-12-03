section .bss
align 16
    width: resd 1
    height: resd 1
    wage: resq 1
    matrix: resq 1

    heaters_count: resd 1
    heaters_x: resq 1
    heaters_y: resq 1
    heaters_temp: resq 1

section .text
global start, place, step

start:
    mov dword [rel width], edi  ; Resolve width
    mov dword [rel height], esi ; Resolve height
    mov qword [rel matrix], rdx ; Resolve a pointer to the matrix
    movss dword [rel wage], xmm1 ; Resolve wage
    ; We are ommiting the coolers temp, as they're stored in the matrix already.

    ret

place:
    mov dword [rel heaters_count], edi ; Resolve the number of heaters.
    mov qword [rel heaters_x], rsi     ; Resolve the x-coordinates of the heaters.
    mov qword [rel heaters_y], rdx     ; Resolve the y-coordinates of the heaters.
    mov qword [rel heaters_temp], rcx  ; Resolve the temperatures of the heaters.

    ret

; Function to execute the step calculating
; next temperature values for the given heat matrix
step:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15

    ; Register r8 will store the full width of the matrix.
    ; (Standard cells + cooler's borders)
    mov r8d, dword [rel width]
    add r8, 2

    ; Register r9 will store the full height of the matrix.
    ; (Standard cells + cooler's borders)
    mov r9d, dword [rel height]
    add r9, 2

    mov rax, r9
    mul r8
    mov r11, rax
    lea r11, [r11 * 4]  ; Register r11 will now store the full size of the matrix (In bytes).

    lea r8, [r8 * 4]    ; Adjust the width to be in bytes.
    lea r9, [r9 * 4]    ; Adjust the height to be in bytes.

    movss xmm2, dword [rel wage]
    shufps xmm2, xmm2, 0h ; Broadcast the wage to all the xmm register's cells.

    mov rax, qword [rel matrix]
    lea r10, [rax + r8 + 4] ; Calculate the address of the first non-cooler cell of the matrix.

    push r10 ; Save the address of the first non-cooler cell of the matrix.

    xor rcx, rcx ; Initialize the row counter to 0.

iterate_height:
    xor rdx, rdx ; Initialize the column counter to 0.

iterate_width:
    ; Iterate over the columns in actual row.
    movss xmm0, dword [r10] ; Initialize the scalar with the current matrix pos value.
    shufps xmm0, xmm0, 0h ; Broadcast the scalar to all 4 floats.

    xorps xmm1, xmm1 ; Clear the xmm1 register, it will now store all 4 neighbours of current cell.

    ; Iterate over neighbors.
    addss xmm1, dword [r10 - 4]  ; Resolve the left neighbor.
    shufps xmm1, xmm1, 93h ; Rotate the scalar to the left.

    addss xmm1, dword [r10 + 4]  ; Resolve the right neighbor.
    shufps xmm1, xmm1, 93h ; Rotate the scalar to the left.

    xor rax, rax
    sub rax, r8 ; Calculate the relative position of the upper neighbor.

    addss xmm1, dword [r10 + rax] ; Resolve the upper neighbor.
    shufps xmm1, xmm1, 93h ; Rotate the scalar to the left.

    addss xmm1, [r10 + r8] ; Resolve the lower neighbor.

    subps xmm1, xmm0       ; Substract the scalar from the difference vector.
    mulps xmm1, xmm2       ; Multiply the difference vector by the wage.

    ; Sum wage differences.
    xor rax, rax           ; Initialize the neighbour counter to 0.

sum_differences:
    inc rax                ; Increment the neighbour counter.
    addss xmm0, xmm1       ; Add the current neighbour wage difference to the scalar.
    shufps xmm1, xmm1, 93h ; Rotate the scalar to the right.

    cmp rax, 3             ; Check if we have reached the end of the neighbours.
    jle sum_differences    ; If not, go back to the sum_differences label.

    movss dword [r10 + r11], xmm0 ; Store the result in the auxiliary matrix.

    inc rdx     ; Increment the column counter.
    add r10, 4  ; Move the cell pointer to the next cell.

    cmp edx, dword [rel width] ; Check if we have reached the end of the columns.
    jl iterate_width ; If not, iterate through the next column.

    inc rcx     ; Increment the row counter.
    add r10, 8  ; Move the cell pointer to the next row.

    cmp ecx, dword [rel height] ; Check if we have reached the end of the rows.
    jl iterate_height ; If not, iterate through the next row.

commit_matrix_changes:
    pop r10 ; Restore the address of the first non-cooler cell of the matrix.

    xor rcx, rcx ; Initialize the row counter to 0.
commit_iterate_rows:
    xor rdx, rdx ; Initialize the column counter to 0.

commit_iterate_columns:
    movss xmm0, dword [r10 + r11]
    movss dword [r10], xmm0

    inc rdx     ; Increment the column counter.
    add r10, 4  ; Move the cell pointer to the next cell.

    cmp edx, dword [rel width] ; Check if we have reached the end of the columns.
    jl commit_iterate_columns ; If not, iterate through the next column.

    inc rcx     ; Increment the row counter.
    add r10, 8  ; Move the cell pointer to the next row.

    cmp ecx, dword [rel height] ; Check if we have reached the end of the rows.
    jl commit_iterate_rows ; If not, iterate through the next row.

restore_heaters_temps:
    mov r12d, dword [rel heaters_count] ; Store the number of heaters.

    cmp r12, 0 ; Check if there are heaters.
    je end     ; If not, go to the end label.

    mov rcx, qword [rel heaters_x] ; Store a pointer to the x coordinates heaters array.
    mov r13, qword [rel heaters_y] ; Store a pointer to the y coordinates heaters array.
    mov r10, qword [rel heaters_temp] ; Store a pointer to the heaters temperatures array.

    xor r11, r11 ; Initialize the heater counter to 0.

    mov r15, qword [rel matrix] ; Store the address of the matrix.
    mov rdx, 5

heaters_loop:
    mov eax, dword [rcx + r11 * 4] ; Store the x coordinate of the current heater.
    inc rax
    mul r8 ; Multiply the x coordinate by the width of the matrix.
    add rax, r15 ; Add the address of the matrix to the x coordinate.

    mov edx, dword [r13 + r11 * 4] ; Store the y coordinate of the current heater.
    inc rdx

    mov r14d, dword [r10 + r11 * 4] ; Store the temperature of the current heater.

    mov dword [rax + rdx * 4], r14d

    inc r11         ; Increment the heater counter.
    cmp r11, r12    ; Check if we have reached the end of the heaters.
    jl heaters_loop ; If not, go back to the heaters_loop label.

end:
    ; Restore the registers.
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx

    ret