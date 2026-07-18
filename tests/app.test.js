import { beforeEach, describe, expect, it, vi } from "vitest";

// app.js auto-runs initApp() on import and reads the module-level PRODUCTS
// array, so each test resets the module registry and rebuilds the DOM
// first, then dynamically imports a fresh copy.
async function loadApp() {
  vi.resetModules();
  document.body.innerHTML = `
    <button class="icon-btn view-toggle" aria-label="Change view"></button>
    <button class="icon-btn cart-btn"><span id="cart-count">0</span></button>
    <section class="product-grid cols-2" id="product-grid"></section>
  `;
  return import("../app.js");
}

beforeEach(() => {
  document.body.innerHTML = "";
});

describe("PRODUCTS data integrity", () => {
  it("gives every product a matching number of colors and images", async () => {
    const { PRODUCTS } = await loadApp();
    for (const product of PRODUCTS) {
      expect(product.images.length).toBe(product.colors.length);
    }
  });

  it("keeps defaultColor within bounds for every product", async () => {
    const { PRODUCTS } = await loadApp();
    for (const product of PRODUCTS) {
      expect(product.defaultColor).toBeGreaterThanOrEqual(0);
      expect(product.defaultColor).toBeLessThan(product.images.length);
    }
  });
});

describe("renderCard", () => {
  it("renders title, price, image, and swatches for a product", async () => {
    const { PRODUCTS, renderCard } = await loadApp();
    const product = PRODUCTS[0];
    const card = renderCard(product);

    expect(card.querySelector(".product-title").textContent).toBe(product.title);
    expect(card.querySelector(".product-price").textContent).toBe(product.price);
    expect(card.querySelector("img").src).toContain(product.images[product.defaultColor]);
    expect(card.querySelectorAll(".swatch").length).toBe(product.colors.length);
    expect(card.querySelector(".swatch.selected").dataset.index).toBe(
      String(product.defaultColor)
    );
  });
});

describe("initApp", () => {
  it("populates the grid with one card per product", async () => {
    const { PRODUCTS } = await loadApp();
    expect(document.querySelectorAll(".product-card").length).toBe(PRODUCTS.length);
  });

  it("swaps the image and moves the selected class when a swatch is clicked", async () => {
    await loadApp();
    const card = document.querySelector(".product-card");
    const [firstSwatch, secondSwatch] = card.querySelectorAll(".swatch");
    const img = card.querySelector("img");
    const originalSrc = img.src;

    secondSwatch.click();

    expect(img.src).not.toBe(originalSrc);
    expect(secondSwatch.classList.contains("selected")).toBe(true);
    expect(firstSwatch.classList.contains("selected")).toBe(false);
  });

  it("increments the cart count each time add-to-bag is clicked, across cards", async () => {
    await loadApp();
    const cartCount = document.getElementById("cart-count");
    const addButtons = document.querySelectorAll(".add-btn");

    addButtons[0].click();
    expect(cartCount.textContent).toBe("1");

    addButtons[1].click();
    expect(cartCount.textContent).toBe("2");
  });

  it("toggles the grid between cols-1 and cols-2 on view-toggle click", async () => {
    await loadApp();
    const grid = document.getElementById("product-grid");
    const toggle = document.querySelector(".view-toggle");

    expect(grid.classList.contains("cols-2")).toBe(true);

    toggle.click();
    expect(grid.classList.contains("cols-1")).toBe(true);
    expect(grid.classList.contains("cols-2")).toBe(false);

    toggle.click();
    expect(grid.classList.contains("cols-2")).toBe(true);
  });

  it("does nothing when the expected DOM is missing", async () => {
    vi.resetModules();
    document.body.innerHTML = "";
    await expect(import("../app.js")).resolves.toBeDefined();
    expect(document.querySelectorAll(".product-card").length).toBe(0);
  });
});
