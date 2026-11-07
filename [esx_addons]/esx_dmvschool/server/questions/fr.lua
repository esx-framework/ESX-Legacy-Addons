-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

return {
  {
    id = 1,
    text = "Si vous allez à 80 km/h, et vous vous approchez d'une zone résidentiel vous devez:",
    answers = {
      'Vous accélérez',
      "Vous gardez votre vitesse, si vous ne voyez pas d'autre voitures",
      'Vous ralentissez',
      'Voud gardez votre vitesse',
    },
    correct = 2,
  },
  {
    id = 2,
    text = "Si vous étiez entrain de tourner à droite à une lumière, mais vous voyez quelqu'un traverser que faites-vous:",
    answers = {
      'Vous passez le piéton',
      "Vous regardez qu'il n'y ai plus de véhicles aux alentours",
      'Vous attendez que le piéton ai passé',
      'Vous tirez le piéton et continuez à conduire',
    },
    correct = 2,
  },
  {
    id = 3,
    text = 'Sans aucune indication, la vitesse permise dans une zone résidentielle est de: __ km/h',
    answers = { '30 km/h', '50 km/h', '40 km/h', '60 km/h' },
    correct = 1,
  },
  {
    id = 4,
    text = 'Avant chaque changement de ligne vous devez:',
    answers = {
      'Regardez vos mirroires',
      'Regardez vos angles mort',
      'Signalez vos intentions',
      "Toutes c'esr réponses",
    },
    correct = 3,
  },
  {
    id = 5,
    text = 'Quel est le taux d’alcoolémie qui est considéré comme conduite avec des facultés affaiblies?',
    answers = { '0.05%', '0.18%', '0.08%', '0.06%' },
    correct = 2,
  },
  {
    id = 6,
    text = 'Quand pouvez-vous continuer à conduire à un feu de signalisation?',
    answers = {
      'Lorsque il est vert',
      "Lorsque personne n'est à l'intersection",
      'Lorsque vous êtes dans une zone écolière',
      "Lorsqie c'est vert et / ou rouge et que vous tourner à droite",
    },
    correct = 3,
  },
  {
    id = 7,
    text = 'Un piéton a un signal indiquant de ne pas traverser, que faites-vous?',
    answers = {
      'Vous les laisser passer',
      'Vous observez avant de continuer',
      'Vous lui faites signe de traverser',
      'Vous continuez car la lumière est verte',
    },
    correct = 3,
  },
  {
    id = 8,
    text = "Qu'est-ce qui est permis pour dépasser un autre véhicule",
    answers = {
      'Vous le suivez de près pour le dépasser plus rapidement',
      'Vous le passez sans quitter la chaussée',
      'Vous conduisez sur la route opposée pour le dépasser',
      'Vous dépassez la limite permise pour le dépasser',
    },
    correct = 2,
  },
  {
    id = 9,
    text = 'Vous conduisez sur une autoroute qui indique une vitesse maximale de 120 km/h. Mais la plupart des conducteurs conduisent à 125 km/h, donc vous ne devriez pas conduire plus vite que:',
    answers = { '120 km/h', '125 km/h', '130 km/h', '110 km/h' },
    correct = 0,
  },
  {
    id = 10,
    text = 'Lorsque vous êtes dépassé par un autre véhicule il est important de NE pas:',
    answers = {
      'Ralentir',
      'Vérifier vos rétroviseurs',
      'Regarder les autres conducteurs',
      'Augmenter votre vitesse',
    },
    correct = 3,
  },
}
