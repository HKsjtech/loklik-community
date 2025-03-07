import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

export default class AdminPluginsPurpleTentacleController extends Controller {
  @tracked menu = {
    showingCuratedPosts: true,
    showingConfig: false,
    showingBanner: false,
  }

  @tracked filteredItems = null;
  @tracked titleSearch = "";
  @tracked isCurated = "";
  @tracked current = 1;
  @tracked total = 0;
  @tracked size = 10;
  @tracked totalPage = 0;

  // 金刚区配置相关内容
  @tracked categoryList = [];
  @tracked selectedCategoryList = [];
  @tracked selectedIdList = [];
  @tracked selectedId0 = 0;
  @tracked selectedId1 = 0;
  @tracked selectedId2 = 0;

  // banner 相关内容
  @tracked bannerList = 0;


  @tracked curatedoptions = [
    // { name: "请选择", id: "" },
    { name: "是", id: "1" },
    { name: "否", id: "0" },
  ];

  constructor() {
    super();
    this.filteredItems = [];
    this.categoryList = [];
    this.selectedCategoryList = [];

    this.loadPosts();
    this.loadCategoryList();
    this.loadBannerList();
  }


  @action
  changeMenu(value) {
    Object.keys(this.menu).forEach(key => {
      this.set(`menu.${key}`, false);
    });
    this.set(`menu.${value}`, true);
  }

  loadPosts() {
    const params = {
      search: this.titleSearch,
      is_curated: this.isCurated,
      page: this.current,
    };
    const paramsStr = new URLSearchParams(params).toString();
    fetch(`/loklik/admin/index.json?${paramsStr}`) // 调用后端 API
      .then((response) => {
        if (!response.ok) {
          throw new Error("Network response was not ok");
        }
        return response.json();
      })
      .then((res) => {
        this.filteredItems = res.data.records.map((item) => {
          item.show_title = this.splitTitle(item.title);
          return item
        });
        this.total = res.data.total;
        this.current = res.data.current;
        this.size = res.data.size;
        this.totalPage = Math.ceil(this.total / this.size);
      })
      .catch((error) => {
        console.error("Error loading items:", error);
      });
  }

  @action
  search() {
    this.loadPosts();
  }

  @action
  reset() {
    this.titleSearch = "";
    this.isCurated = "";
    this.loadPosts();
  }

  @action
  curated(item, new_is_curated) {
    const csrfToken = document
      .querySelector('meta[name="csrf-token"]')
      .getAttribute("content");
    fetch(`/loklik/admin/curated/${item.id}.json`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken, // 添加 CSRF Token
      },
      body: JSON.stringify({
        is_curated: new_is_curated,
        topic_id: item.id,
      }),
    })
      .then((response) => {
        if (!response.ok) {
          throw new Error("Network response was not ok");
        }
        this.loadPosts();
      })
      .catch((error) => {
        console.error("Error curating item:", error);
      });
  }

  @action
  goPerPage(page) {
    this.current = Math.max(this.current - 1, 1);
    this.loadPosts();
  }

  @action
  goNextPage(page) {
    this.current = Math.min(
      this.current + 1,
      Math.ceil(this.total / this.size)
    );
    this.loadPosts();
  }

  loadCategoryList() {
    fetch(`/loklik/admin/categories.json`) // 调用后端 API
      .then((response) => {
        if (!response.ok) {
          throw new Error("Network response was not ok");
        }
        return response.json();
      })
      .then((res) => {
        this.categoryList = res.data;
        this.loadSelectedCategoryList(); // 先加载分类列表，再加载已选分类列表
      })
      .catch((error) => {
        console.error("Error loading items:", error);
      });
  }

  loadBannerList() {
    fetch(`/loklik/admin/banner/list.json`) // 调用后端 API
      .then((response) => {
        if (!response.ok) {
          throw new Error("Network response was not ok");
        }
        return response.json();
      })
      .then((res) => {
        this.bannerList = res.data;
      })
      .catch((error) => {
        console.error("Error loading items:", error);
      });
  }

  loadSelectedCategoryList() {
    fetch(`/loklik/admin/select_categories.json`) // 调用后端 API
      .then((response) => {
        if (!response.ok) {
          throw new Error("Network response was not ok");
        }
        return response.json();
      })
      .then((res) => {
        this.selectedCategoryList = res.data;
        const selectedIdList = this.selectedCategoryList.map(
          (item) => +item.categories_id
        );
        this.selectedId0 = selectedIdList[0];
        this.selectedId1 = selectedIdList[1];
        this.selectedId2 = selectedIdList[2];
      })
      .catch((error) => {
        console.error("Error loading items:", error);
      });
  }

  @action
  updateSelectedCategory0(value) {
    this.selectedId0 = +value;
  }

  @action
  updateSelectedCategory1(value) {
    this.selectedId1 = +value;
  }

  @action
  updateSelectedCategory2(value) {
    this.selectedId2 = +value;
  }

  @action
  setSelectedCategories() {
    let len = [...new Set([this.selectedId0, this.selectedId1, this.selectedId2])].length;
    if (len !== 3) {
      alert("请确保三个分类不同");
      return;
    }

    this.selectedCategoryList[0].categories_id = this.selectedId0;
    this.selectedCategoryList[1].categories_id = this.selectedId1;
    this.selectedCategoryList[2].categories_id = this.selectedId2;

    const csrfToken = document
      .querySelector('meta[name="csrf-token"]')
      .getAttribute("content");
    fetch(`/loklik/admin/set_select_categories.json`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken, // 添加 CSRF Token
      },
      body: JSON.stringify(this.selectedCategoryList),
    })
      .then((response) => {
        if (!response.ok) {
          throw new Error("Network response was not ok");
        }
        alert("保存成功");
        this.loadSelectedCategoryList();
      })
      .catch((error) => {
        console.error("Error curating item:", error);
      });
  }


  splitTitle(title) {
    const maxLength = 20;
    if (title.length > maxLength) {
      return title.substring(0, maxLength) + '...';
    }
    return title;
  }
}
