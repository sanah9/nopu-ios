use std::process;
use uniffi_bindgen::bindings::SwiftBindingGenerator;
use camino::Utf8Path;

fn main() {
    println!("🔧 Generating Swift bindings...");
    
    let udl_path = Utf8Path::new("src/nopu_ffi.udl");
    let out_dir = Utf8Path::new("target/bindings");
    
    // Create output directory
    std::fs::create_dir_all(out_dir).unwrap_or_else(|e| {
        eprintln!("❌ Failed to create output directory: {}", e);
        process::exit(1);
    });
    
    // Generate Swift bindings
    let generator = SwiftBindingGenerator::new();
    
    match uniffi_bindgen::generate_bindings(
        udl_path,
        None, // Config file
        vec![generator].into_iter(),
        Some(out_dir),
        None, // Library file
        None, // Library directory
        false // Don't skip formatting
    ) {
        Ok(_) => println!("✅ Swift bindings generated successfully! Output directory: {}", out_dir),
        Err(e) => {
            eprintln!("❌ Failed to generate bindings: {}", e);
            process::exit(1);
        }
    }
} 