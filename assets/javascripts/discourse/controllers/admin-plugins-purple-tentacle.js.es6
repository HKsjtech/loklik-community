import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

export default class AdminPluginsPurpleTentacleController extends Controller {
  @tracked menu = {
    showingCuratedPosts: true,
    showingConfig: false,
    showingBanner: false,
    showingBanner2: false,
    showingScore: false,
    showingScore2: false,
  };

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
    this.loadScoreEvents();
    this.loadUsers();
  }

  @action
  changeMenu(value) {
    Object.keys(this.menu).forEach((key) => {
      this.set(`menu.${key}`, false);
    });
    this.set(`menu.${value}`, true);
    this.initBannerForm();
  }

  async loadPosts() {
    const params = {
      search: this.titleSearch,
      is_curated: this.isCurated,
      page: this.current,
    };
    const paramsStr = new URLSearchParams(params).toString();
    const res = await this.fetch("GET", `/loklik/admin/index.json?${paramsStr}`);
    this.filteredItems = res.data.records.map((item) => {
      item.show_title = this.splitTitle(item.title);
      item.show_updated_at = item.updated_at.substring(0, 10);
      return item;
    });
    this.total = res.data.total;
    this.current = res.data.current;
    this.size = res.data.size;
    this.totalPage = Math.ceil(this.total / this.size);
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
  async curated(item, new_is_curated) {
    await this.fetch(
      "PUT",
      `/loklik/admin/curated/${item.id}.json`,
      {
        is_curated: new_is_curated,
        topic_id: item.id,
      }
    );
    this.loadPosts();
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

  async loadCategoryList() {
    const res = await this.fetch("GET", `/loklik/admin/categories.json`);
    this.categoryList = res.data;
    this.loadSelectedCategoryList(); // 先加载分类列表，再加载已选分类列表
  }

  async loadSelectedCategoryList() {
    const res = await this.fetch("GET", `/loklik/admin/select_categories.json`);
    this.selectedCategoryList = res.data;
    const selectedIdList = this.selectedCategoryList.map(
      (item) => +item.categories_id
    );
    this.selectedId0 = selectedIdList[0];
    this.selectedId1 = selectedIdList[1];
    this.selectedId2 = selectedIdList[2];
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
  async setSelectedCategories() {
    let len = [
      ...new Set([this.selectedId0, this.selectedId1, this.selectedId2]),
    ].length;
    if (len !== 3) {
      alert("请确保三个分类不同");
      return;
    }

    this.selectedCategoryList[0].categories_id = this.selectedId0;
    this.selectedCategoryList[1].categories_id = this.selectedId1;
    this.selectedCategoryList[2].categories_id = this.selectedId2;

    await this.fetch(
      "POST",
      `/loklik/admin/set_select_categories.json`,
      this.selectedCategoryList
    );
    alert("保存成功");
  }

  splitTitle(title) {
    const maxLength = 20;
    if (title.length > maxLength) {
      return title.substring(0, maxLength) + "...";
    }
    return title;
  }

  @tracked bannerStatus = [
    // { name: "请选择", id: "" },
    { name: "未上架", id: "0" },
    { name: "已上架", id: "1" },
  ];

  // banner 相关内容
  @tracked bannerList = 0;
  @tracked bannerSearch = {
    name: undefined,
    status: undefined,
  };

  @tracked bannerForm = {
    id: 0,
    name: "",
    appImageUrl: "",
    padImageUrl: "",
    linkUrl: "",
    sort: "",
  };

  async loadBannerList() {
    const params = {};
    if (this.bannerSearch.name) {
      params.name = this.bannerSearch.name;
    }
    if (this.bannerSearch.status) {
      params.status = this.bannerSearch.status;
    }
    const paramsStr = new URLSearchParams(params).toString();
    const res = await this.fetch(
      "GET",
      `/loklik/admin/banner/list.json?${paramsStr}`
    );
    this.bannerList = res.data;
  }

  @action
  uploadBannerImage(event) {
    const file = event.target.files[0];
    if (!file) return;

    const csrfToken = document
      .querySelector('meta[name="csrf-token"]')
      .getAttribute("content");

    const formData = new FormData();
    formData.append("file", file);

    fetch("/loklik/admin/upload_image.json", {
      method: "POST",
      headers: {
        "X-CSRF-Token": csrfToken,
      },
      body: formData,
    })
      .then((response) => {
        if (!response.ok) {
          throw new Error("上传失败");
        }
        return response.json();
      })
      .then((data) => {
        const imageUrl = data.data.url;
        // 根据input的id判断是app还是paid图片
        if (event.target.id === "appImageUrl") {
          this.bannerForm.appImageUrl = imageUrl;
          this.set("bannerForm.appImageUrl", imageUrl);
        } else if (event.target.id === "paidImageUrl") {
          this.bannerForm.paidImageUrl = imageUrl;
          this.set("bannerForm.paidImageUrl", imageUrl);
        }
      })
      .catch((error) => {
        console.error("上传失败:", error);
        alert("上传失败");
      });
  }

  @action
  async saveBanner() {
    // 构建请求数据
    const formData = {
      name: this.bannerForm.name,
      app_image_url: this.bannerForm.appImageUrl,
      pad_image_url: this.bannerForm.paidImageUrl,
      link_url: this.bannerForm.linkUrl,
      sort: this.bannerForm.sort,
      status: this.bannerForm.status,
    };

    if (this.bannerForm.id) {
      this.updateBanner(this.bannerForm.id, formData);
    } else {
      const res = await this.fetch(
        "POST",
        "/loklik/admin/banner/create.json",
        formData
      );
      alert("保存成功");
      // 重置表单
      this.initBannerForm();
      // 返回列表页
      this.changeMenu("showingBanner");
      // 重新加载列表
      this.loadBannerList();
    }
  }

  initBannerForm(banner) {
    if (banner) {
      this.bannerForm = {
        id: banner.id,
        name: banner.name,
        appImageUrl: banner.app_image_url,
        padImageUrl: banner.pad_image_url,
        linkUrl: banner.link_url,
        sort: banner.sort,
        status: banner.status,
      };
    } else {
      this.bannerForm = {
        name: "",
        appImageUrl: "",
        padImageUrl: "",
        linkUrl: "",
        sort: "",
        status: "",
      };
    }
  }

  @action
  offlineBanner(item) {
    this.updateBanner(item.id, { status: 0 });
  }

  @action
  onlineBanner(item) {
    this.updateBanner(item.id, { status: 1 });
  }

  @action
  searchBanner() {
    this.loadBannerList();
  }

  @action
  showUpdateBannerForm(item) {
    this.changeMenu("showingBanner2");
    this.initBannerForm(item);
  }

  async updateBanner(id, update_obj) {
    // 构建请求数据
    const formData = {
      id: id,
      ...update_obj,
    };

    await this.fetch("PUT", "/loklik/admin/banner/update.json", formData)
    // 重置表单
    this.initBannerForm();
    // 返回列表页
    this.changeMenu("showingBanner");
    // 重新加载列表
    this.loadBannerList();
    alert("保存成功");
  }

  // ======================================  score
  @tracked scoreEvents = "";
  @tracked scoreUserNameSearch = "";
  @tracked scoreDateSearch = "";
  @tracked scoreForm = {
    userId: "",
    points: 0,
    description: "",
  };
  @tracked userList = [];
  @tracked scoreFormuserId = "";
  @tracked scoreCurrent = 1;
  @tracked scoreTotal = 1;
  @tracked scoreTotalPage = 1;

  async loadUsers() {
    const params = {
      page: 1,
      size: 999999,
    };
    const paramsStr = new URLSearchParams(params).toString();
    const res = await this.fetch("GET", `/loklik/admin/users.json?${paramsStr}`)
    this.userList = res.data.records.map((item) => ({
      id: item.id,
      name: item.username + ": " + item.email,
    }));
  }


  async loadScoreEvents() {
    const params = {
      username: this.scoreUserNameSearch,
      date: this.scoreDateSearch,
      page: this.scoreCurrent,
    };
    const paramsStr = new URLSearchParams(params).toString();
    const res = await this.fetch("GET", `/loklik/admin/score/events.json?${paramsStr}`)
    this.scoreEvents = res.data.records;
    this.scoreTotal = res.data.total;
    this.scoreCurrent = res.data.current;
    this.size = res.data.size;
    this.scoreTotalPage = Math.ceil(this.scoreTotal / this.size);
  }

  initScoreForm() {
    this.scoreForm = {
      userId: "",
      points: 0,
      description: "",
    };
  }

  @action
  async saveScoreForm() {
    await this.fetch("POST", "/loklik/admin/score/events.json", {
      user_id: this.scoreForm.userId,
      points: this.scoreForm.points,
      description: this.scoreForm.description,
    })
    this.loadScoreEvents()
    this.initScoreForm()
    alert("积分发放成功")
  }

  @action
  scoreGoPerPage() {
    this.scoreCurrent = Math.max(this.scoreCurrent - 1, 1);
    this.loadScoreEvents()
  }

  @action
  scoreGoNextPage() {
    this.scoreCurrent = Math.min(
      this.scoreCurrent + 1,
      Math.ceil(this.scoreTotal / this.size)
    );
    this.loadScoreEvents()
  }

  @action
  searchScore() {
    this.scoreCurrent = 1; // 重置页码
    this.loadScoreEvents()
  }

  async fetch(method, uri, data) {
    // 获取CSRF令牌
    const csrfToken = document.querySelector("meta[name='csrf-token']").content;

    // 发送保存请求
    try {
      const res = await fetch(uri, {
        method: method,
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
        },
        body: JSON.stringify(data),
      });
      if (!res.ok) {
        throw new Error("Network response was not ok");
      }
      if (res.status === 204){
       return {}
      }
      return res.json();
    } catch (error) {
      console.error("请求发送失败:", error);
    }
  }


}
