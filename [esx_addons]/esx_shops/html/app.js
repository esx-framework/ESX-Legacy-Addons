$(function () {
  const resourceName =
    typeof GetParentResourceName === "function"
      ? GetParentResourceName()
      : "esx_shops";

  function nuiPost(action, payload) {
    $.post(`https://${resourceName}/${action}`, JSON.stringify(payload || {}));
  }

  $(".Container").hide();

  // State
  let categories = [];
  let items = [];
  let activeCategoryId = null;
  let searchTerm = "";
  const cartByName = {}; // name -> { def, amount }

  const $categories = $(".Categories-Scroller");
  const $items = $(".Shop-Items");
  const $basket = $(".Right-Shop-Basket");
  const $basketEmpty = $(".Right-Shop-Basket .Basket-Empty");
  const $totalPrice = $(".Right-Shop-End-Price span").last();

  function formatPrice(value) {
    return `${value}$`;
  }

  function getFilteredItems() {
    return items.filter((i) => {
      const matchesCat = !activeCategoryId || i.category === activeCategoryId;
      const matchesSearch =
        !searchTerm || (i.label || i.name).toLowerCase().includes(searchTerm);
      return matchesCat && matchesSearch;
    });
  }

  function renderCategories() {
    $categories.empty();
    categories.forEach((c, idx) => {
      const $el = $(`<div class="Categories-Wrap">${c.label}</div>`);
      if (!activeCategoryId && idx === 0) activeCategoryId = c.id;
      if (c.id === activeCategoryId) $el.addClass("active");
      $el.on("click", () => {
        activeCategoryId = c.id;
        renderCategories();
        renderItems();
      });
      $categories.append($el);
    });
  }

  function createItemCard(item) {
    const $card = $(`
            <div class="Item">
                <div class="Item-Info">
                    <div class="Item-Label"></div>
                    <div class="Item-Price"></div>
                </div>
                <div class="Item-Image">
                    <img alt="">
                </div>
                <div class="Item-Cart">
                    <div class="Item-Cart-Icon"><i class="fa-solid fa-basket-shopping"></i></div>
                    <div class="Item-Cart-Label">Add to Cart</div>
                </div>
            </div>
        `);
    $card.find(".Item-Label").text(item.label || item.name);
    $card.find(".Item-Price").text(`$ ${item.price}`);
    $card.find("img").attr("src", item.image || "");
    $card
      .find(".Item-Cart")
      .on("click", () => addToCart(item, item.amount || 1));
    return $card;
  }

  function renderItems() {
    $items.empty();
    const list = getFilteredItems();
    list.forEach((item) => {
      $items.append(createItemCard(item));
    });
  }

  function recomputeTotal() {
    let total = 0;
    Object.values(cartByName).forEach((entry) => {
      total += entry.def.price * entry.amount;
    });
    $totalPrice.text(formatPrice(total));
  }

  function renderBasket() {
    $basket.find(".Basket-Item").remove();
    const entries = Object.values(cartByName);
    if (entries.length === 0) {
      $basketEmpty.show();
    } else {
      $basketEmpty.hide();
    }
    entries.forEach((entry) => {
      const { def, amount } = entry;
      const $row = $(`
                <div class="Basket-Item">
                    <div class="Basket-Item-LeftSection">
                        <div class="Basket-Item-Img"><img alt=""></div>
                        <div class="Basket-Item-Info">
                            <div class="Basket-Item-Label"></div>
                            <div class="Basket-Item-Price"></div>
                        </div>
                    </div>
                    <div class="Basket-Item-RightSection">
                        <div class="Basket-Item-Count">
                            <div class="Count-Options">
                                <button class="decrease" id="decrease">−</button>
                                <input type="number" class="count" id="count" min="1"/>
                                <button class="increase" id="increase">+</button>
                            </div>
                        </div>
                        <div class="Count-Remove"><i class="fa-solid fa-x"></i></div>
                    </div>
                </div>
            `);
      $row.find("img").attr("src", def.image || "");
      $row.find(".Basket-Item-Label").text(def.label || def.name);
      $row.find(".Basket-Item-Price").text(`${def.price} $`);
      const $count = $row.find("input.count");
      $count.val(amount);
      $row
        .find("button.decrease")
        .on("click", () =>
          updateCart(def.name, cartByName[def.name].amount - 1)
        );
      $row
        .find("button.increase")
        .on("click", () =>
          updateCart(def.name, cartByName[def.name].amount + 1)
        );
      $count.on("change", () =>
        updateCart(def.name, parseInt($count.val(), 10) || 1)
      );
      $row.find(".Count-Remove").on("click", () => removeFromCart(def.name));
      $basket.append($row);
    });
    recomputeTotal();
  }

  function addToCart(def, addAmount) {
    const maxQty = 100; 
    const name = def.name;
    if (!cartByName[name]) {
      cartByName[name] = { def, amount: 0 };
    }
    const prevAmount = cartByName[name].amount;
    cartByName[name].amount = Math.min(
      maxQty,
      cartByName[name].amount + (addAmount || 1)
    );
    const addedNow = cartByName[name].amount - prevAmount;
    if (addedNow > 0) {
      console.log(
        `[Shop] Added to basket: ${
          def.label || def.name
        } x${addedNow} (total: ${cartByName[name].amount})`
      );
    } else {
      console.warn(
        `[Shop] Not added: ${def.label || def.name} (reached max ${maxQty})`
      );
    }
    renderBasket();
  }

  function updateCart(name, newAmount) {
    if (!cartByName[name]) return;
    if (newAmount <= 0) {
      delete cartByName[name];
    } else {
      const maxQty = 100;
      cartByName[name].amount = Math.min(maxQty, newAmount);
    }
    renderBasket();
  }

  function removeFromCart(name) {
    if (cartByName[name]) {
      delete cartByName[name];
      renderBasket();
    }
  }

  function getCartPayload() {
    const cart = [];
    Object.values(cartByName).forEach((entry) => {
      cart.push({ name: entry.def.name, amount: entry.amount });
    });
    return cart;
  }

  function checkout(method) {
    const cart = getCartPayload();
    if (cart.length === 0) return;
    $.post(
      `https://${resourceName}/purchase`,
      JSON.stringify({ method, cart }),
      function (resp) {
        try {
          const data = typeof resp === "string" ? JSON.parse(resp) : resp;
          if (data && data.success) {
            Object.keys(cartByName).forEach((k) => delete cartByName[k]);
            renderBasket();
          } else {
          }
        } catch (_) {}
      }
    );
  }

  window.addEventListener("message", function (event) {
    const data = event.data || {};
    switch (data.action) {
      case "show":
        $(".Container").stop(true, true).fadeIn(150);
        $.post(
          `https://${resourceName}/getShopData`,
          JSON.stringify({}),
          function (resp) {
            try {
              const payload =
                typeof resp === "string" ? JSON.parse(resp) : resp;
              categories = payload.categories || [];
              items = payload.items || [];
              activeCategoryId = (categories[0] && categories[0].id) || null;
              renderCategories();
              renderItems();
              renderBasket();
            } catch (_) {}
          }
        );
        break;
      case "hide":
        $(".Container").stop(true, true).fadeOut(150);
        break;
    }
  });

  $(".Shop-close").on("click", function () {
    nuiPost("close");
  });

  $(document).on("keydown", function (e) {
    if (e.key === "Escape") {
      nuiPost("close");
    }
  });

  $(".Shop-search input[type=text]").on("input", function () {
    searchTerm = ($(this).val() || "").toString().toLowerCase();
    renderItems();
  });

  $(".Right-Shop-End-Button .Cash").on("click", function () {
    checkout("cash");
  });
  $(".Right-Shop-End-Button .Bank").on("click", function () {
    checkout("bank");
  });
});
