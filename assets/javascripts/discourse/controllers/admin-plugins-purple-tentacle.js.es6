import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

export default class AdminPluginsPurpleTentacleController extends Controller {
  @tracked filteredItems = null;
  @tracked titleSearch = "";
  @tracked isCurated = "";
  @tracked current = 1;
  @tracked total = 0;
  @tracked size = 10;
  @tracked totalPage = 0;

  constructor() {
    super();
    this.filteredItems = [];
    this.loadPosts();
  }

  loadPosts() {
    const params= {
      search: this.titleSearch,
      is_featured: this.isFeatured,
      is_curated: this.isCurated,
      page: this.current
    };
    const paramsStr = new URLSearchParams(params).toString();
    fetch(`/loklik/admin/index.json?${paramsStr}`) // 调用后端 API
      .then(response => {
        if (!response.ok) {
          throw new Error('Network response was not ok');
        }
        return response.json();
      })
      .then(res => {
        this.filteredItems = res.data.records;
        this.total = res.data.total;
        this.current = res.data.current;
        this.size = res.data.size;
        this.totalPage = Math.ceil(this.total/this.size);
      })
      .catch(error => {
        console.error('Error loading items:', error);
      });
  }

  @action
  search() {
    console.log("searching...", this.titleSearch, this.isFeatured);
    this.loadPosts();
  }

  @action
  reset() {
    this.titleSearch = "";
    this.isFeatured =  "";
    this.loadPosts();
  }

  @action
  curated(item, new_is_curated) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content');
    fetch(`/loklik/admin/curated/${item.id}.json`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken // 添加 CSRF Token
      },
      body: JSON.stringify({
        is_curated: new_is_curated,
        topic_id: item.id
      })
    })
      .then(response => {
        if (!response.ok) {
          throw new Error('Network response was not ok');
        }
        this.loadPosts();
      })
      .catch(error => {
        console.error('Error curating item:', error);
      });
  }

  @action
  goPerPage(page) {
    this.current = Math.max(this.current - 1, 1);
    this.loadPosts();
  }

  @action
  goNextPage(page) {
    this.current = Math.min(this.current + 1, Math.ceil(this.total/this.size));
    this.loadPosts();
  }
}
