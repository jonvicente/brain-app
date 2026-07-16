

library(shiny)
library(jsonlite)
library(tools)
library(bslib)

# ----------------- 1. Mesh Files -----------------
seg_folder <- "/Users/jonathanvicente/Documents/GitHub/brain-app/www/pial_DK_obj"
seg_files <- list.files(seg_folder, pattern = "\\.obj$", full.names = FALSE)
seg_files <- paste0("pial_DK_obj/", seg_files)
seg_regions <- file_path_sans_ext(basename(seg_files))
seg_json <- toJSON(setNames(seg_files, seg_regions))

hemi_folder <- "/Users/jonathanvicente/Documents/GitHub/brain-app/www/pial_Full_obj"
hemi_files <- list.files(hemi_folder, pattern = "\\.obj$", full.names = FALSE)
hemi_files <- paste0("pial_Full_obj/", hemi_files)
hemi_names <- file_path_sans_ext(basename(hemi_files))
hemi_json <- toJSON(setNames(hemi_files, hemi_names))

# ----------------- 2. Brain Info -----------------
brain_info <- list(
  precuneus = list(
    anatomy = "Located in the medial parietal cortex, involved in visuospatial imagery and consciousness.",
    func = "Supports self-related processing and episodic memory.",
    climate = "Sensitive to stress and disrupted sleep patterns, both worsening with climate instability.",
    references = "Fletcher et al., 2021; Vanhaudenhuyse et al., 2010"
  ),
  hippocampus = list(
    anatomy = "Medial temporal lobe structure critical for memory formation.",
    func = "Encodes and retrieves episodic memories.",
    climate = "Pollution and wildfire smoke impair the hippocampus, reducing memory-related volume.",
    references = "Goshen et al., 2021; Muñoz et al., 2018"
  ),
  amygdala = list(
    anatomy = "Located deep in the temporal lobe; processes emotions.",
    func = "Detects threats and modulates stress responses.",
    climate = "Climate anxiety and particulate pollution increase inflammatory load on the amygdala.",
    references = "Phelps & LeDoux, 2005; Janiri et al., 2020"
  ),
  frontal_cortex = list(
    anatomy = "Covers the anterior part of the brain; includes prefrontal cortex.",
    func = "Executive functions, decision-making, attention.",
    climate = "Heat waves impair decision-making and executive functions.",
    references = "Gao et al., 2018; Racine et al., 2020"
  ),
  temporal_lobe = list(
    anatomy = "Lateral portion of the cerebral cortex, houses auditory and language areas.",
    func = "Processes auditory information and contributes to memory.",
    climate = "Air pollution accelerates temporal-lobe degeneration and increases dementia risk.",
    references = "Power et al., 2016; Weuve et al., 2012"
  )
)

# ----------------- 3. UI -----------------
ui <- fluidPage(
  theme = bs_theme(version = 5, bootswatch = "flatly"),
  
  tags$style("
    #brain-container { width: 800px; height: 800px; margin:auto; border-radius:14px; background:#fafafa; box-shadow:0 0 18px rgba(0,0,0,0.15); }
    #hoverLabel { position:fixed; padding:6px 10px; background:rgba(0,0,0,0.75); color:white; border-radius:6px; pointer-events:none; opacity:0; transition:opacity 0.15s; z-index:20000; font-size:14px; }
    #infoPanel { position:fixed; top:0; right:-420px; width:400px; height:100%; background:white; box-shadow:-3px 0 8px rgba(0,0,0,0.3); z-index:9999; transition:right 0.4s ease; overflow-y:auto; padding:15px; font-family:'Helvetica Neue', sans-serif; }
    #infoPanel h3 { margin-top:0; }
    #infoTabs { display:flex; margin-bottom:10px; }
    #infoTabs button { flex:1; padding:6px 10px; border:none; background:#eee; cursor:pointer; font-weight:bold; border-radius:4px 4px 0 0; margin-right:2px; }
    #infoTabs button.active { background:#ddd; }
    #infoContent div { display:none; }
    #infoContent div.active { display:block; }
    #closePanel { margin-top:10px; padding:6px 12px; background:#c44; color:white; border:none; border-radius:4px; cursor:pointer;}
  "),
  
  tags$div(id = "hoverLabel"),
  titlePanel("Interactive Brain Atlas – Climate Effects"),
  fluidRow(column(width=12, tags$div(id="brain-container"))),
  
  # Sliding info panel
  tags$div(
    id="infoPanel",
    h3(id="panelTitle","Brain Region"),
    tags$div(
      id="infoTabs",
      tags$button(class="active", `data-tab`="anatomy","Anatomy"),
      tags$button(`data-tab`="func","Function"),
      tags$button(`data-tab`="climate","Climate"),
      tags$button(`data-tab`="references","References")
    ),
    tags$div(
      id="infoContent",
      tags$div(id="anatomy", class="active",""),
      tags$div(id="func",""),
      tags$div(id="climate",""),
      tags$div(id="references","")
    ),
    tags$button("Close", id="closePanel")
  ),
  
  # Three.js
  tags$script(src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r134/three.min.js"),
  tags$script(src="https://cdn.jsdelivr.net/npm/three@0.134.0/examples/js/loaders/OBJLoader.js"),
  tags$script(src="https://cdn.jsdelivr.net/npm/three@0.134.0/examples/js/controls/OrbitControls.js"),
  
  # Three.js loader + hover + click
  tags$script(HTML(sprintf("
    const segFiles = %s;
    const hemiFiles = %s;
    const container = document.getElementById('brain-container');
    const hoverLabel = document.getElementById('hoverLabel');
    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(75,1,0.1,2000);
    const renderer = new THREE.WebGLRenderer({antialias:true});
    renderer.setSize(container.clientWidth, container.clientHeight);
    container.appendChild(renderer.domElement);

    const controls = new THREE.OrbitControls(camera, renderer.domElement);
    camera.position.set(0,0,220);

    scene.add(new THREE.AmbientLight(0xffffff,0.5));
    const dirLight = new THREE.DirectionalLight(0xffffff,1.0); dirLight.position.set(120,80,160); scene.add(dirLight);

    const loader = new THREE.OBJLoader();
    const raycaster = new THREE.Raycaster();
    const mouse = new THREE.Vector2();
    const regionMeshes = [];
    let highlighted = null;

    // Load hemispheres
    for(const hemiName in hemiFiles){
      loader.load(hemiFiles[hemiName], obj=>{
        obj.traverse(child=>{
          if(child instanceof THREE.Mesh){
            child.material = new THREE.MeshPhongMaterial({color:0xdddddd, transparent:true, opacity:0.25});
          }
        });
        scene.add(obj);
      });
    }

    // Load segmentation
    for(const regionName in segFiles){
      loader.load(segFiles[regionName], obj=>{
        obj.traverse(child=>{
          if(child instanceof THREE.Mesh){
            child.userData.regionName = regionName;
            child.material = new THREE.MeshPhongMaterial({color:new THREE.Color().setHSL(Math.random(),0.45,0.65),emissive:0x000000});
            regionMeshes.push(child);
          }
        });
        scene.add(obj);
      });
    }

    // Hover
    renderer.domElement.addEventListener('mousemove', event=>{
      const rect = renderer.domElement.getBoundingClientRect();
      mouse.x = ((event.clientX-rect.left)/rect.width)*2-1;
      mouse.y = -((event.clientY-rect.top)/rect.height)*2+1;
      raycaster.setFromCamera(mouse,camera);
      const hits = raycaster.intersectObjects(regionMeshes,true);
      if(hits.length>0){
        const mesh = hits[0].object;
        const region = mesh.userData.regionName;
        if(highlighted!==mesh){ if(highlighted) highlighted.material.emissive.setHex(0x000000); mesh.material.emissive.setHex(0x333333); highlighted=mesh;}
        hoverLabel.style.left = event.clientX+10+'px';
        hoverLabel.style.top = event.clientY+10+'px';
        hoverLabel.innerHTML = region;
        hoverLabel.style.opacity = 1;
        renderer.domElement.style.cursor='pointer';
      }else{
        if(highlighted) highlighted.material.emissive.setHex(0x000000);
        highlighted=null;
        hoverLabel.style.opacity=0;
        renderer.domElement.style.cursor='default';
      }
    });

    // Click
    renderer.domElement.addEventListener('click', event=>{
      const rect = renderer.domElement.getBoundingClientRect();
      mouse.x = ((event.clientX-rect.left)/rect.width)*2-1;
      mouse.y = -((event.clientY-rect.top)/rect.height)*2+1;
      raycaster.setFromCamera(mouse,camera);
      const hits = raycaster.intersectObjects(regionMeshes,true);
      if(hits.length>0){
        const region = hits[0].object.userData.regionName;
        Shiny.setInputValue('clicked_region',region,{priority:'event'});
      }
    });

    function animate(){ requestAnimationFrame(animate); controls.update(); renderer.render(scene,camera);}
    animate();
  ", seg_json, hemi_json))),
  
  # Tab switching & panel handlers
  tags$script(HTML("
    const tabs = document.querySelectorAll('#infoTabs button');
    const contents = document.querySelectorAll('#infoContent div');
    tabs.forEach(tab => {
      tab.onclick = function(){
        tabs.forEach(t=>t.classList.remove('active'));
        contents.forEach(c=>c.classList.remove('active'));
        this.classList.add('active');
        document.getElementById(this.dataset.tab).classList.add('active');
      };
    });

    Shiny.addCustomMessageHandler('openPanel', function(msg){
      document.getElementById('infoPanel').style.right='0px';
    });
    Shiny.addCustomMessageHandler('closePanel', function(msg){
      document.getElementById('infoPanel').style.right='-420px';
    });
    Shiny.addCustomMessageHandler('setPanelTitle', function(title){
      document.getElementById('panelTitle').innerHTML = title;
    });

    document.getElementById('closePanel').onclick=function(){
      Shiny.setInputValue('closePanel', Math.random());
    };
  "))
)

# ----------------- 4. Server -----------------
server <- # This returns the full path to your current working directory
function(input, output, session){
  observeEvent(input$clicked_region,{
    region <- tolower(input$clicked_region)
    info <- brain_info[[region]]
    if(is.null(info)) info <- list(anatomy="N/A", func="N/A", climate="N/A", references="N/A")
    
    output$anatomy <- renderText(info$anatomy)
    output$func <- renderText(info$func)
    output$climate <- renderText(info$climate)
    output$references <- renderText(info$references)
    
    session$sendCustomMessage("openPanel", TRUE)
    session$sendCustomMessage("setPanelTitle", tools::toTitleCase(region))
  })
  
  observeEvent(input$closePanel,{
    session$sendCustomMessage("closePanel", TRUE)
  })
}

# ----------------- 5. Run -----------------
shinyApp(ui, server)


#library(rsconnect)
#  rsconnect::deployApp('~/Library/CloudStorage/OneDrive-UniversitaetBern/Brain App')



