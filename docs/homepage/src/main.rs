use dioxus::prelude::*;

static MAIN_CSS: Asset = asset!("/assets/main.css");

fn main() {
    dioxus::launch(app);
}

fn app() -> Element {
    rsx! {
        document::Stylesheet { href: MAIN_CSS }

        Router::<Route> { }
    }
}

#[derive(Routable, Clone, PartialEq, Debug)]
enum Route {
    #[route("/")]
    Home {},
}

#[component]
fn Home() -> Element {
    rsx! {
        header {
            h1 { a { href: "/", "lightmix" } }
        }
    }
}
