// Product data — swap `images` entries for real product photos
// (each color key maps to its own image).
export const PRODUCTS = [
  {
    id: 1,
    title: "Blazer with linen rolled-up sleeves",
    price: "3,590 EGP",
    colors: ["#1a1a1a", "#d8c9a3"],
    defaultColor: 0,
    images: ["images/look-1-black.svg", "images/look-1-beige.svg"],
  },
  {
    id: 2,
    title: "Blazer with linen rolled-up sleeves",
    price: "3,590 EGP",
    colors: ["#d8c9a3", "#1a1a1a"],
    defaultColor: 0,
    images: ["images/look-2-beige.svg", "images/look-2-black.svg"],
  },
  {
    id: 3,
    title: "Blazer with linen rolled-up sleeves",
    price: "3,590 EGP",
    colors: ["#d8c9a3", "#1a1a1a"],
    defaultColor: 0,
    images: ["images/look-3-beige.svg", "images/look-3-black.svg"],
  },
  {
    id: 4,
    title: "ZW collection cropped jacket",
    price: "4,990 EGP",
    colors: ["#1a1a1a", "#f2f2f2"],
    defaultColor: 0,
    images: ["images/look-4-black.svg", "images/look-4-white.svg"],
  },
  {
    id: 5,
    title: "Straight-leg trousers with darts",
    price: "2,990 EGP",
    colors: ["#1a1a1a", "#d8c9a3"],
    defaultColor: 0,
    images: ["images/look-5-black.svg", "images/look-5-beige.svg"],
  },
  {
    id: 6,
    title: "Oversized poplin shirt",
    price: "2,290 EGP",
    colors: ["#f2f2f2", "#d8c9a3"],
    defaultColor: 0,
    images: ["images/look-6-white.svg", "images/look-6-beige.svg"],
  },
];

// Builds one product card. No listeners are attached here — click handling
// is delegated once on the grid (see initApp) so cost stays O(1) in the
// number of products instead of O(n) event listeners.
export function renderCard(product) {
  const card = document.createElement("article");
  card.className = "product-card";
  card.dataset.images = JSON.stringify(product.images);

  const swatches = product.colors
    .map(
      (color, i) => `
      <button class="swatch${i === product.defaultColor ? " selected" : ""}"
              data-index="${i}" aria-label="Colour option ${i + 1}">
        <i style="background:${color}"></i>
      </button>`
    )
    .join("");

  card.innerHTML = `
    <div class="product-media">
      <img src="${product.images[product.defaultColor]}" alt="${product.title}" loading="lazy" />
    </div>
    <div class="product-info">
      <div class="product-title-row">
        <h2 class="product-title">${product.title}</h2>
        <button class="add-btn" aria-label="Add to bag">
          <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.2">
            <line x1="8" y1="1" x2="8" y2="15" />
            <line x1="1" y1="8" x2="15" y2="8" />
          </svg>
        </button>
      </div>
      <p class="product-price">${product.price}</p>
      <div class="swatches">${swatches}</div>
    </div>`;

  return card;
}

// Renders all product cards into `grid` in a single reflow via a
// DocumentFragment, instead of one reflow per appendChild call.
export function renderProducts(grid, products = PRODUCTS) {
  const fragment = document.createDocumentFragment();
  products.forEach((product) => fragment.appendChild(renderCard(product)));
  grid.appendChild(fragment);
}

export function initApp(doc = document) {
  const grid = doc.getElementById("product-grid");
  const cartCount = doc.getElementById("cart-count");
  const viewToggle = doc.querySelector(".view-toggle");

  if (!grid || !cartCount) return;

  let itemsInCart = 0;

  renderProducts(grid);

  // Single delegated listener handles swatch swaps and add-to-bag clicks
  // for every card, present and future, instead of per-button listeners.
  grid.addEventListener("click", (event) => {
    const swatch = event.target.closest(".swatch");
    if (swatch) {
      const card = swatch.closest(".product-card");
      card.querySelector(".swatch.selected")?.classList.remove("selected");
      swatch.classList.add("selected");
      const images = JSON.parse(card.dataset.images);
      card.querySelector("img").src = images[Number(swatch.dataset.index)];
      return;
    }

    const addBtn = event.target.closest(".add-btn");
    if (addBtn) {
      itemsInCart += 1;
      cartCount.textContent = itemsInCart;
    }
  });

  viewToggle?.addEventListener("click", () => {
    grid.classList.toggle("cols-1");
    grid.classList.toggle("cols-2");
  });
}

// Auto-run in the browser; no-op if the expected DOM isn't present
// (e.g. when this module is imported in a test before the DOM is set up).
initApp();
