$(window).ready(function () {
  window.addEventListener("message", function (event) {
    let data = event.data;

    if (data.showMenu) {
      $("#container").css({ display: 'grid', opacity: 0 }).animate({ opacity: 1 }, 200);
      $("#menu").show();

      if (data.type === "impound") {
        $("#header ul").hide();
      } else {
        $("#header ul").show();
      }

      if (data.vehiclesList != undefined) {
        $("#container").data("spawnpoint", data.spawnPoint);
        if (data.poundCost) $("#container").data("poundcost", data.poundCost);

        if (data.poundCost != undefined) {
          $(".content .vehicle-list").html(
            getVehicles(data.locales, data.vehiclesList, data.poundCost)
          );
        } else {
          $(".content .vehicle-list").html(
            getVehicles(data.locales, data.vehiclesList)
          );
        }

        $(".content h2").hide();
      } else {
        $(".content h2").show();
        $(".content .vehicle-list").empty();
      }

      if (data.vehiclesImpoundedList != undefined) {
        $(".impounded_content").data("poundName", data.poundName);
        $(".impounded_content").data("poundSpawnPoint", data.poundSpawnPoint);

        if (data.poundCost) $("#container").data("poundcost", data.poundCost);

        $(".impounded_content .vehicle-list").html(
          getImpoundedVehicles(data.locales, data.vehiclesImpoundedList)
        );
        $(".impounded_content h2").hide();
      } else {
        $(".impounded_content h2").show();
        $(".impounded_content .vehicle-list").empty();
      }

      // Locales

      // needs a rework
      // $(".content h2").html(function (i, text) {
      //   return text.replace("No vehicle in this garage.", data.locales.no_veh_parking);
      // });

      // $(".impounded_content h2").html(function (i, text) {
      //   return text.replace("No vehicle impounded.", data.locales.no_veh_impounded);
      // });

      $(".vehicle-listing").html(function (i, text) {
        return text.replace("Model", data.locales.veh_model);
      });
      $(".vehicle-listing").html(function (i, text) {
        return text.replace("Plate", data.locales.veh_plate);
      });
      $(".vehicle-listing").html(function (i, text) {
        return text.replace("Condition", data.locales.veh_condition);
      });
    } else if (data.hideAll) {
      $("#container").stop(true, true).fadeOut(150, function(){
        $(this).css('display','none');
      });
    }
  });

  $("#container").hide();

  $(".close").click(function (event) {
    $("#container").hide();
    $.post("https://esx_garage/escape", "{}");

    $(".impounded_content").hide();
    $(".content").show();
    $('li[data-page="garage"]').addClass("selected");
    $('li[data-page="impounded"]').removeClass("selected");
  });

  document.onkeyup = function (data) {
    if (data.which == 27) {
      $.post("https://esx_garage/escape", "{}");

      $(".impounded_content").hide();
      $(".content").show();
      $('li[data-page="garage"]').addClass("selected");
      $('li[data-page="impounded"]').removeClass("selected");
    }
  };

  function clamp(n, min, max){ return Math.max(min, Math.min(max, n)); }

  function getVehicles(locale, vehicle, amount = null) {
    let html = "";
    let vehicleData = JSON.parse(vehicle);
    let bodyHealth = 1000;
    let engineHealth = 1000;
    let tankHealth = 1000;
    let vehicleDamagePercent = "";

    for (let i = 0; i < vehicleData.length; i++) {
      const p = vehicleData[i].props || {};
      const b = typeof p.bodyHealth === 'number' ? p.bodyHealth : 1000;
      const e = typeof p.engineHealth === 'number' ? p.engineHealth : 1000;
      const t = typeof p.tankHealth === 'number' ? p.tankHealth : 1000;

      bodyHealth = clamp((b / 1000) * 100, 0, 100);
      engineHealth = clamp((e / 1000) * 100, 0, 100);
      tankHealth = clamp((t / 1000) * 100, 0, 100);

      const percentNumber = clamp(Math.round(((bodyHealth + engineHealth + tankHealth) / 300) * 100), 0, 100);
      vehicleDamagePercent = percentNumber + "%";

      const model = String(vehicleData[i].model || '').toLowerCase();
      const plate = String(vehicleData[i].plate || '').toLowerCase();

      html += "<div class='vehicle-listing' data-model='" + model + "' data-plate='" + plate + "'>";
      html += "<div>Model: <strong>" + vehicleData[i].model + "</strong></div>";
      html += "<div>Plate: <strong>" + vehicleData[i].plate + "</strong></div>";
      html +=
        "<div class='condition'><span>Condition</span><div class='bar'><div class='fill' style='width:" + vehicleDamagePercent + "'></div></div><strong class='percent'>" + vehicleDamagePercent + "</strong></div>";
      html +=
        "<button data-button='spawn' class='vehicle-action unstyled-button' data-vehprops='" +
        JSON.stringify(vehicleData[i].props) +
        "'>" +
        locale.action +
        (amount ? " ($" + amount + ")" : "") +
        "</button>";
      html += "</div>";
    }

    return html;
  }

  function getImpoundedVehicles(locale, vehicle) {
    let html = "";
    let vehicleData = JSON.parse(vehicle);
    let bodyHealth = 1000;
    let engineHealth = 1000;
    let tankHealth = 1000;
    let vehicleDamagePercent = "";

    for (let i = 0; i < vehicleData.length; i++) {
      const p = vehicleData[i].props || {};
      const b = typeof p.bodyHealth === 'number' ? p.bodyHealth : 1000;
      const e = typeof p.engineHealth === 'number' ? p.engineHealth : 1000;
      const t = typeof p.tankHealth === 'number' ? p.tankHealth : 1000;

      bodyHealth = clamp((b / 1000) * 100, 0, 100);
      engineHealth = clamp((e / 1000) * 100, 0, 100);
      tankHealth = clamp((t / 1000) * 100, 0, 100);

      const percentNumber = clamp(Math.round(((bodyHealth + engineHealth + tankHealth) / 300) * 100), 0, 100);
      vehicleDamagePercent = percentNumber + "%";

      const model = String(vehicleData[i].model || '').toLowerCase();
      const plate = String(vehicleData[i].plate || '').toLowerCase();

      html += "<div class='vehicle-listing' data-model='" + model + "' data-plate='" + plate + "'>";
      html += "<div>Model: <strong>" + vehicleData[i].model + "</strong></div>";
      html += "<div>Plate: <strong>" + vehicleData[i].plate + "</strong></div>";
      html +=
        "<div class='condition'><span>Condition</span><div class='bar'><div class='fill' style='width:" + vehicleDamagePercent + "'></div></div><strong class='percent'>" + vehicleDamagePercent + "</strong></div>";
      html +=
        "<button data-button='impounded' class='vehicle-action red unstyled-button' data-vehprops='" +
        JSON.stringify(vehicleData[i].props) +
        "'>" +
        locale.impound_action +
        "</button>";
      html += "</div>";
    }

    return html;
  }

  function applyFilter($container, query) {
    const q = String(query || '').trim().toLowerCase();
    const $cards = $container.find('.vehicle-listing');
    if (!q) {
      $cards.show();
      return;
    }
    $cards.each(function () {
      const model = String($(this).data('model') || '');
      const plate = String($(this).data('plate') || '');
      if (model.indexOf(q) !== -1 || plate.indexOf(q) !== -1) {
        $(this).show();
      } else {
        $(this).hide();
      }
    });
  }

  $(document).on('input', '#search-garage', function () {
    applyFilter($('.content .vehicle-list'), $(this).val());
  });
  $(document).on('input', '#search-impounded', function () {
    applyFilter($('.impounded_content .vehicle-list'), $(this).val());
  });

  // Helpers (none for now)

  $('li[data-page="garage"]').click(function (event) {
    $(".impounded_content").hide();
    $(".content").show();
    $('li[data-page="garage"]').addClass("selected");
    $('li[data-page="impounded"]').removeClass("selected");
  });

  $('li[data-page="impounded"]').click(function (event) {
    $(".content").hide();
    $(".impounded_content").show();
    $('li[data-page="impounded"]').addClass("selected");
    $('li[data-page="garage"]').removeClass("selected");
  });

  $(document).on(
    "click",
    "button[data-button='spawn'].vehicle-action",
    function (event) {
      let spawnPoint = $("#container").data("spawnpoint");
      let poundCost = $("#container").data("poundcost");
      let vehicleProps = $(this).data("vehprops");

      // prevent empty cost
      if (poundCost === undefined) poundCost = 0;

      $.post(
        "https://esx_garage/spawnVehicle",
        JSON.stringify({
          vehicleProps: vehicleProps,
          spawnPoint: spawnPoint,
          exitVehicleCost: poundCost,
        })
      );

      $(".impounded_content").hide();
      $(".content").show();
      $('li[data-page="garage"]').addClass("selected");
      $('li[data-page="impounded"]').removeClass("selected");
    }
  );

  $(document).on(
    "click",
    "button[data-button='impounded'].vehicle-action",
    function (event) {
      let vehicleProps = $(this).data("vehprops");
      let poundName = $(".impounded_content").data("poundName");
      let poundSpawnPoint = $(".impounded_content").data("poundSpawnPoint");
      $.post(
        "https://esx_garage/impound",
        JSON.stringify({
          vehicleProps: vehicleProps,
          poundName: poundName,
          poundSpawnPoint: poundSpawnPoint,
        })
      );

      $(".impounded_content").hide();
      $(".content").show();
      $('li[data-page="garage"]').addClass("selected");
      $('li[data-page="impounded"]').removeClass("selected");
    }
  );
});
