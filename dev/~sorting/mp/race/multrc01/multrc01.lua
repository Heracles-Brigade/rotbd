local game = require("mp_race");
game({
  {
    name = "check_point1",
    paths = {"p_check2"}
  },
  {
    name = "check_point2",
    paths = {"p_check3"}
  },
  {
    name = "check_point3",
    paths = {"p_check4"},
  },
  {
    name = "check_point4",
    paths = {"p_check5"},
  },
  {
    name = "check_point5",
    paths = {"p_check6"},
  },
  {
    name = "check_point6",
    paths = {"p_check1"},
  }
});