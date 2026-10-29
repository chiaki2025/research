
import numpy as np

H_IN, W_IN, C = 112, 112, 32
K_H, K_W = 3, 3
STRIDE = 1
PADDING = 1
PADDING_SAME = 1
PADDING_VALID = 0

np.random.seed(42)


def depthwise_conv2d_int8(X, W, padding=1, stride=1):
    H_in, W_in, C_in = X.shape
    K_h, K_w, C_w = W.shape

    assert C_in == C_w

    if padding > 0:
        X_padded = np.pad(
            X,
            ((padding, padding), (padding, padding), (0, 0)),
            mode="constant",
            constant_values=0
        )
    else:
        X_padded = X

    H_out = (H_in + 2 * padding - K_h) // stride + 1
    W_out = (W_in + 2 * padding - K_w) // stride + 1

    Y = np.zeros((H_out, W_out, C_in), dtype=np.int32)

    X_padded_32 = X_padded.astype(np.int32)
    W_32 = W.astype(np.int32)

    for h in range(H_out):
        for w in range(W_out):
            h_start = h * stride
            w_start = w * stride

            window = X_padded_32[
                h_start:h_start + K_h,
                w_start:w_start + K_w,
                :
            ]

            Y[h, w, :] = np.sum(
                window * W_32,
                axis=(0, 1)
            )

    return Y


def check_one_output(X, W, Y, h, w, c, padding, stride):
    H_in, W_in, _ = X.shape
    K_h, K_w, _ = W.shape

    expected = 0

    for i in range(K_h):
        for j in range(K_w):
            x_h = h * stride + i - padding
            x_w = w * stride + j - padding

            if 0 <= x_h < H_in and 0 <= x_w < W_in:
                expected += (
                    int(X[x_h, x_w, c])
                    * int(W[i, j, c])
                )

    actual = int(Y[h, w, c])

    assert actual == expected, (
        f"Mismatch at ({h}, {w}, {c}): "
        f"actual={actual}, expected={expected}"
    )


def export_to_txt(filename, array_data, is_hex=True):
    flat_data = array_data.flatten()

    with open(filename, "w") as f:
        for val in flat_data:
            v = int(val)

            if is_hex:
                if array_data.dtype == np.int32:
                    v_hex = v & 0xFFFFFFFF
                    f.write(f"{v_hex:08x}\n")
                else:
                    v_hex = v & 0xFF
                    f.write(f"{v_hex:02x}\n")
            else:
                f.write(f"{v}\n")

    print(f"-> Exported: {filename} ({len(flat_data)} values)")


def generate_all_testcases():
    tests = {}

    # 1. Zero input and weights
    X = np.zeros((H_IN, W_IN, C), dtype=np.int8)
    W = np.zeros((K_H, K_W, C), dtype=np.int8)
    tests["tc1_1_all_zeros"] = (
        X, W, PADDING_SAME, STRIDE
    )

    # 2. Single impulse
    X = np.zeros((H_IN, W_IN, C), dtype=np.int8)
    W = np.zeros((K_H, K_W, C), dtype=np.int8)
    X[0, 0, 0] = 100
    W[1, 1, 0] = 50
    tests["tc1_2_single_impulse"] = (
        X, W, PADDING_SAME, STRIDE
    )

    # 3. All ones
    X = np.ones((H_IN, W_IN, C), dtype=np.int8)
    W = np.ones((K_H, K_W, C), dtype=np.int8)
    tests["tc1_3_all_ones"] = (
        X, W, PADDING_SAME, STRIDE
    )

    # 4. Alternating signs
    pattern = np.array(
        [[10, -10], [-10, 10]],
        dtype=np.int8
    )
    X = np.tile(
        pattern,
        (H_IN // 2, W_IN // 2)
    )[:, :, None]
    X = np.tile(X, (1, 1, C)).astype(np.int8)

    pattern_w = np.array(
        [[-5, 5], [5, -5]],
        dtype=np.int8
    )
    W = np.tile(
        pattern_w[:, :, None],
        (2, 2, C)
    )[:K_H, :K_W, :]

    tests["tc1_4_alternating_signs"] = (
        X, W, PADDING_SAME, STRIDE
    )

    # 5. INT8 minimum values
    X = np.full(
        (H_IN, W_IN, C), -128, dtype=np.int8
    )
    W = np.full(
        (K_H, K_W, C), -128, dtype=np.int8
    )
    tests["tc1_5_int8_minimum"] = (
        X, W, PADDING_SAME, STRIDE
    )

    # 6. Channel independence
    X = np.zeros((H_IN, W_IN, C), dtype=np.int8)
    W = np.zeros((K_H, K_W, C), dtype=np.int8)

    for ch in range(C):
        X[:, :, ch] = ch + 1
        W[:, :, ch] = ch + 1

    tests["tc1_6_channel_diversity"] = (
        X, W, PADDING_SAME, STRIDE
    )

    # 7. Borders and corners
    X = np.zeros((H_IN, W_IN, C), dtype=np.int8)
    W = np.ones((K_H, K_W, C), dtype=np.int8)

    X[0, 0, :] = 127
    X[0, -1, :] = 127
    X[-1, 0, :] = 127
    X[-1, -1, :] = 127
    X[0, W_IN // 2, :] = 64
    X[-1, W_IN // 2, :] = 64

    tests["tc2_1_corners_borders"] = (
        X, W, PADDING_SAME, STRIDE
    )

    # 8. Small tensor with VALID padding
    X = np.random.randint(
        -128, 128, size=(5, 5, 4), dtype=np.int8
    )
    W = np.random.randint(
        -128, 128, size=(K_H, K_W, 4), dtype=np.int8
    )
    tests["tc3_1_small_valid"] = (
        X, W, PADDING_VALID, STRIDE
    )

    # 9. Full-size random input
    X = np.random.randint(
        -128, 128, size=(H_IN, W_IN, C), dtype=np.int8
    )
    W = np.random.randint(
        -128, 128, size=(K_H, K_W, C), dtype=np.int8
    )
    tests["tc4_1_random_reference"] = (
        X, W, PADDING_SAME, STRIDE
    )

    return tests


if __name__ == "__main__":
    test_suite = generate_all_testcases()

    for name, (X, W, pad, stride) in test_suite.items():
        print(f"\nProcessing: {name}")
        print(f"Input:  {X.shape}, dtype={X.dtype}")
        print(f"Weight: {W.shape}, dtype={W.dtype}")

        Y = depthwise_conv2d_int8(
            X, W, padding=pad, stride=stride
        )

        print(f"Output: {Y.shape}, dtype={Y.dtype}")

        # Independent checks on the random test
        if name == "tc4_1_random_reference":
            for h, w, c in [
                (0, 0, 0),
                (0, 50, 12),
                (50, 50, 16),
                (111, 111, 31),
                (70, 23, 7),
            ]:
                check_one_output(
                    X, W, Y, h, w, c, pad, stride
                )

            print("PASS: Independent scalar checks")

        export_to_txt(
            f"{name}_input.txt", X, is_hex=True
        )
        export_to_txt(
            f"{name}_weight.txt", W, is_hex=True
        )
        export_to_txt(
            f"{name}_golden_output.txt", Y, is_hex=True
        )

    print("\nAll test vectors generated.")
